require "bundler/setup"
require "k8s-client"
require "concurrent"
require 'logger'
require 'yaml'
require 'mail'
require 'json'

require_relative "k8s_client"

Mail.defaults do
  delivery_method :smtp, address: ENV["EMAIL_SMTP_HOST"], port: ENV["EMAIL_SMTP_PORT"], user_name: ENV["EMAIL_SMTP_USERNAME"], password: ENV["EMAIL_SMTP_PASSWORD"]
end

class Controller
  TIMEOUT = 3600*24*365

  def initialize
    @percona_namespace = ENV.fetch("PERCONA_NAMESPACE", "percona-l")

    @k8s_client = Kubernetes::Client.new
    @logger = Logger.new(STDOUT)
  end

  def start
    $stdout.sync = true

    t1 = Thread.new do
      watch_resources :backups
    end.join
  end

  private

  attr_reader :percona_namespace, :k8s_client, :logger

  def notify(event)
    logger.info "notifying"
    backup_hash = JSON.parse(event.resource.to_json)

    if backup_hash.key?('kind') && backup_hash.key?('metadata') && backup_hash['metadata'].key?('name')
      if backup_hash.key?('status') && backup_hash['status'].key?('state')
        state = backup_hash['status']['state']
      else
        state = "Running"
      end

      email_subject = "pxc-backup #{state}"
      email_body = "Run kubectl describe pxc #{backup_hash['metadata']['name']} for more details"
    else
      email_subject = "pxc-backup resource is incomplete or doesn't exist"
      email_body = "please check kubectl get pxc-backup and kubectl get pods"

      logger.warn email_subject
    end

    logger.info email_subject

    if ENV.fetch("ENABLE_EMAIL_NOTIFICATIONS", "false") =~ /true/i
      logger.info "notifying by email"
      begin
        mail = Mail.new do
          from    "#{ENV['EMAIL_FROM_SENDER_NAME']} <#{ENV["EMAIL_FROM_ADDRESS"]}>"
          to      ENV["EMAIL_TO_ADDRESS"]
          subject "#{ENV.fetch("EMAIL_SUBJECT_PREFIX", "[Percona]")} #{email_subject}"
          body    "#{email_body}"
        end

        mail.deliver!
      rescue => e
        logger.error "Something went wrong with the email notification: #{e.message}"
      end
    end

  end

  def watch_resources(resource_type)
    resource_version = k8s_client.api("pxc.percona.com/v1/").resource("perconaxtradbclusterbackups").meta_list.metadata.resourceVersion

    begin
      logger.info "Watching ..."
      logger.info resource_version
      k8s_client.api("pxc.percona.com/v1").resource("perconaxtradbclusterbackups").watch(timeout: TIMEOUT, resourceVersion: resource_version) do |event|
        logger.info "iteration ..."
        resource_version = event.resource.metadata.resourceVersion
        logger.info resource_version

        notify event
        logger.info "End watching"
      end

    rescue EOFError, Excon::Error::Socket
      logger.info "Reconnecting to API..."
      retry
    end
  end
end

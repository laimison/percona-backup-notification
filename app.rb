require_relative "lib/controller"

K8s::Logging.debug!
K8s::Transport.verbose!

Controller.new.start

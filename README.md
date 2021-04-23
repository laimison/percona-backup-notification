# percona-backup-notification

This is a simple Kubernetes controller to monitor backup progress for [Percona XtraDB Kubernetes operator](https://github.com/percona/percona-xtradb-cluster-operator). This tool notifies by email when backup is in state:

* Created

* Running

* Failed

* Succeeded

The emails are classified by subject, e.g.:

* [production] pxc-backup Created

* [production] pxc-backup Running

* [production] pxc-backup Failed

* [production] pxc-backup Succeeded

In the email's body, you will see which exact backup object is started, but not progressing or as desired succeeding.

If your mail client classifies emails by subject in groups, you will see only these items.

The pod (controller) is started in Percona DB namespace and monitors backups which are usually listed with command `kubectl get pxc-backup -n <namespace>`, but it does it at Kubernetes apiserver level by watching a backup object.

## Installation

Clone repo, make sure you have `helm` and `kubectl` installed and it points to your target cluster where Percona DB backups are scheduled

```bash
helm install ./helm \
  --name percona-backup-notification \
  --namespace percona-l \
  --set percona_namespace=percona-l \
  --set email.enabled=true \
  --set email.smtp.host=smtp.gmail.com \
  --set email.smtp.port=587 \
  --set email.smtp.username=your-username-95712363910@gmail.com \
  --set email.smtp.password=your-password \
  --set email.from_address=your-email-from-95712363910@gmail.com \
  --set email.to_address=your-email-to-95712363910@gmail.com \
  --set email.subject_prefix="[development]" \
  --set email.from_sender_name="Company X"
```

That's it

## Uninstall

Delete these resources

```
kubectl get deploy -n percona-l | grep percona-backup-notification
kubectl get clusterrolebinding | grep percona-backup-notification
kubectl get clusterrole | grep percona-backup-notification
kubectl get sa -n percona-l | grep percona-backup-notification-sa
kubectl get secret -n percona-l | grep percona-backup-notification

```

## Development only

Building Docker container

```
cd percona-backup-notification
docker login --username=laimison
docker build -t percona-backup-notification .
docker images | head
docker tag taghere laimison/percona-backup-notification:latest
docker push laimison/percona-backup-notification:latest

docker tag taghere laimison/percona-backup-notification:0.1
docker push laimison/percona-backup-notification:0.1
```

You can access the pod and check what is returned by Kuberntes apiserver

```
curl -v --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes.default.svc/apis/pxc.percona.com/v1/perconaxtradbclusterbackups | jq .
```

## Thanks

Special thanks to https://github.com/vitobotta for the base of the code, that is used in this controller

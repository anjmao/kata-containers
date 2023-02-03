set -e

# Install Grafana and Prometheus.
helm upgrade -i grafana grafana --repo https://grafana.github.io/helm-charts -n hack --create-namespace -f ./grafana-values.yaml
helm upgrade -i prom prometheus --repo https://prometheus-community.github.io/helm-charts -n hack -f ./prom-values.yaml

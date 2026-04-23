.PHONY: forward-app forward-argo forward-jenkins forward-grafana forward-prometheus

forward-app:
	@echo "🚀 Abrindo a API em http://localhost:8000"
	kubectl port-forward svc/app 8000:80

forward-argo:
	@echo "🐙 Abrindo o Argo CD em https://localhost:8081"
	kubectl port-forward svc/argocd-server -n argocd 8081:443

forward-jenkins:
	@echo "👷 Abrindo o Jenkins em http://localhost:8080"
	kubectl port-forward svc/jenkins -n jenkins 8080:8080

forward-grafana:
	@echo "📊 Abrindo o Grafana em http://localhost:3000"
	kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

forward-prometheus:
	@echo "🔥 Abrindo o Prometheus em http://localhost:9090"
	kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
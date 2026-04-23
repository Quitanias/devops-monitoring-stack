import pytest
from fastapi.testclient import TestClient
from src.main import app


@pytest.fixture
def client():
    """Cria um cliente de teste para a aplicação FastAPI."""
    return TestClient(app)


class TestHealthCheck:
    """Testes para o endpoint de health check."""

    def test_status_returns_ok(self, client):
        """Testa se GET /status retorna status 200 com resposta ok."""
        response = client.get("/status")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    def test_status_response_contains_status_field(self, client):
        """Testa se a resposta contém o campo 'status'."""
        response = client.get("/status")
        data = response.json()
        assert "status" in data
        assert isinstance(data["status"], str)


class TestDataEndpoint:
    """Testes para o endpoint de dados."""

    def test_data_returns_200(self, client):
        """Testa se GET /data retorna status 200."""
        response = client.get("/data")
        assert response.status_code == 200

    def test_data_returns_valid_json(self, client):
        """Testa se GET /data retorna um JSON válido."""
        response = client.get("/data")
        data = response.json()
        assert isinstance(data, (dict, list))


class TestMetricsEndpoint:
    """Testes para o endpoint de métricas Prometheus."""

    def test_metrics_returns_200(self, client):
        """Testa se GET /metrics retorna status 200."""
        response = client.get("/metrics")
        assert response.status_code == 200

    def test_metrics_content_type(self, client):
        """Testa se o content-type é text/plain para métricas Prometheus."""
        response = client.get("/metrics")
        assert "text/plain" in response.headers.get("content-type", "")

    def test_metrics_contains_prometheus_format(self, client):
        """Testa se a resposta contém métricas no formato Prometheus."""
        response = client.get("/metrics")
        text = response.text
        assert "http_requests_total" in text or "# HELP" in text


class TestRequestMetrics:
    """Testes para validação de coleta de métricas."""

    def test_metrics_incremented_after_request(self, client):
        """Testa se as métricas são incrementadas após uma requisição."""
        # Faz uma requisição
        client.get("/status")
        
        # Verifica se as métricas foram registradas
        response = client.get("/metrics")
        assert response.status_code == 200
        assert "http_requests_total" in response.text

    def test_multiple_requests_tracked(self, client):
        """Testa se múltiplas requisições são rastreadas."""
        # Faz múltiplas requisições
        for _ in range(3):
            response = client.get("/status")
            assert response.status_code == 200
        
        # Verifica se as métricas foram atualizadas
        response = client.get("/metrics")
        assert response.status_code == 200

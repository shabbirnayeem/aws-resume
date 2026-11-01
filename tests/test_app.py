import pytest

from app import app


@pytest.fixture
def client():
    return app.test_client()


def test_home_renders_portfolio(client):
    response = client.get('/')
    assert response.status_code == 200
    assert b'~/</span>projects' in response.data


def test_healthz(client):
    response = client.get('/healthz')
    assert response.status_code == 200
    assert response.get_json() == {'status': 'ok'}


@pytest.mark.parametrize('path', [
    '/static/css/portfolio.css',
    '/static/js/portfolio.js',
    '/static/images/profile.jpg',
    '/static/images/favicon.png',
])
def test_static_assets_exist(client, path):
    assert client.get(path).status_code == 200


def test_debug_is_off_by_default():
    assert app.debug is False

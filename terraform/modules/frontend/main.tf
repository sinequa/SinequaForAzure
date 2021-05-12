
resource "azurerm_availability_set" "sinequa_as" {
  name                      = var.availability_set_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tags                      = var.tags
}

resource "azurerm_public_ip" "sinequa_ag_pip" {
  name                      = "pip-${var.application_gateway_name}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  allocation_method         = "Static"
  sku                       = "Standard"
  domain_name_label         = var.dns_name
  tags                      = var.tags
}


resource "azurerm_application_gateway" "sinequa_ag" {
  name                      = var.application_gateway_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tags                      = var.tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "HTTPS"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "appGwFrontendIp"
    public_ip_address_id = azurerm_public_ip.sinequa_ag_pip.id
  }

  backend_address_pool {
    name = "sinequaBackendPool"
  }

  backend_http_settings {
    name                  = "HTTP"
    cookie_based_affinity = "Enabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    affinity_cookie_name  = "SQApplicationGatewayAffinity"
  }

  http_listener {
    name                           = "httpslistener"
    frontend_ip_configuration_name = "appGwFrontendIp"
    frontend_port_name             = "HTTPS"
    protocol                       = "Https"
    ssl_certificate_name           = var.certificate.name
  }

  request_routing_rule {
    name                       = "HTTPS"
    rule_type                  = "Basic"
    http_listener_name         = "httpslistener"
    backend_address_pool_name  = "sinequaBackendPool"
    backend_http_settings_name = "HTTP"
  }
  
  dynamic "identity" {
    for_each = var.kv_identity_reader[*]
    content {
      identity_ids = identity.value.identity_ids
    }
  }

  ssl_certificate {
    name                        = var.certificate.name
    data                        = var.certificate.data
    password                    = var.certificate.password
    key_vault_secret_id         = var.certificate.key_vault_secret_id
  }               
}



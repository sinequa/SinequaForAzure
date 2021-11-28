
resource "azurerm_virtual_network" "sinequa_vnet" {
  name                      = var.vnet_name
  address_space             = ["10.3.0.0/16"]
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tags                      = var.tags
}

resource "azurerm_subnet" "subnet_app" {
  name                 = var.subnet_app_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.sinequa_vnet.name
  address_prefixes     = ["10.3.1.0/24"]
}

resource "azurerm_subnet" "subnet_front" {
  count                = var.require_front_subnet?1:0
  name                 = var.subnet_front_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.sinequa_vnet.name
  address_prefixes     = ["10.3.2.0/24"]
}

resource "azurerm_network_security_group" "sinequa_nsg_front" {
  count                     = var.require_front_subnet?1:0
  name                      = var.nsg_front_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tags                      = var.tags
 
  security_rule = [ {
    name                        = "Appgatewayskuv2"
    description                 = ""
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "*"
    source_port_range           = "*"
    source_port_ranges          = []
    source_address_prefixes     = []
    source_application_security_group_ids = []
    destination_port_range      = "65200-65535"
    destination_port_ranges     = []
    destination_address_prefixes = []
    destination_application_security_group_ids = []
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  },
  {
    name                        = "https"
    description                 = ""
    priority                    = 110
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    source_port_ranges          = []
    source_address_prefixes     = []
    source_application_security_group_ids = []
    destination_port_range      = "443"
    destination_port_ranges     = []
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    destination_address_prefixes = []
    destination_application_security_group_ids = []
  }]
}

resource "azurerm_network_security_group" "sinequa_nsg_app" {
  name                      = var.nsg_app_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tags                      = var.tags
}

resource "azurerm_network_security_rule" "rdp_on_app" {
  count                       = var.allow_http_on_app_nsg?1:0
  name                        = "RDP"
  description                 = ""
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_application_security_group_ids = []
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  destination_application_security_group_ids = []
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.sinequa_nsg_app.name

  depends_on = [azurerm_network_security_group.sinequa_nsg_app]
}

resource "azurerm_network_security_rule" "http_on_app" {
  count                       = var.allow_http_on_app_nsg?1:0
  name                        = "http"
  description                 = ""
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_application_security_group_ids = []
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  destination_application_security_group_ids = []
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.sinequa_nsg_app.name

  depends_on = [azurerm_network_security_group.sinequa_nsg_app]
}

resource "azurerm_subnet_network_security_group_association" "sinequa_subnet_nsg_app" {
  subnet_id                 = azurerm_subnet.subnet_app.id
  network_security_group_id = azurerm_network_security_group.sinequa_nsg_app.id
}

resource "azurerm_subnet_network_security_group_association" "sinequa_subnet_nsg_front" {
  count                     = var.require_front_subnet?1:0
  subnet_id                 = azurerm_subnet.subnet_front[0].id
  network_security_group_id = azurerm_network_security_group.sinequa_nsg_front[0].id
}


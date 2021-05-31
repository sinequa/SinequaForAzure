
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
  name                 = var.subnet_front_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.sinequa_vnet.name
  address_prefixes     = ["10.3.2.0/24"]
}

resource "azurerm_network_security_group" "sinequa_nsg_front" {
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
    priority                    = 120
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

  security_rule = [ {
    access = "Allow"
    description = "RDP"
    destination_address_prefix = "*"
    destination_address_prefixes = []
    destination_application_security_group_ids = []
    destination_port_range = "3389"
    destination_port_ranges = []
    direction = "Inbound"
    name = "RDP"
    priority = 300
    protocol = "Tcp"
    source_address_prefix = "*"
    source_address_prefixes = []
    source_application_security_group_ids = []
    source_port_range = "*"
    source_port_ranges = []
  } ]
}

resource "azurerm_subnet_network_security_group_association" "sinequa_subnet_nsg_app" {
  subnet_id                 = azurerm_subnet.subnet_app.id
  network_security_group_id = azurerm_network_security_group.sinequa_nsg_app.id
}

resource "azurerm_subnet_network_security_group_association" "sinequa_subnet_nsg_front" {
  subnet_id                 = azurerm_subnet.subnet_front.id
  network_security_group_id = azurerm_network_security_group.sinequa_nsg_front.id
}


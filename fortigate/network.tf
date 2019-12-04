resource "oci_core_virtual_network" "my_vcn" {
  cidr_block     = "${var.vcn_cidr}"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "my-vcn"
  dns_label      = "myvcn"
}

//if you want to point to an existing vcn, use data source
// data "oci_core_virtual_networks" "my_vcn" {
//   compartment_id = "${var.compartment_ocid}"
// }

resource "oci_core_internet_gateway" "igw" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "igw"
  vcn_id         = "${oci_core_virtual_network.my_vcn.id}"
}

####################################
## UNTRUST NETWORK SETTINGS   ##
###################################

resource "oci_core_route_table" "untrust_routetable" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.my_vcn.id}"
  display_name   = "untrust-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.igw.id}"
  }
}

resource "oci_core_subnet" "untrust_subnet" {
  cidr_block          = "${var.untrust_subnet_cidr}"
  display_name        = "untrust"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_virtual_network.my_vcn.id}"
  route_table_id      = "${oci_core_route_table.untrust_routetable.id}"
  security_list_ids   = ["${oci_core_virtual_network.my_vcn.default_security_list_id}", "${oci_core_security_list.untrust_security_list.id}"]
  dhcp_options_id     = "${oci_core_virtual_network.my_vcn.default_dhcp_options_id}"
  dns_label           = "untrust"
}

# Protocols are specified as protocol numbers.
# http://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
resource "oci_core_security_list" "untrust_security_list" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.my_vcn.id}"
  display_name   = "untrust-security-list"

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }

  // allow inbound http (port 80) traffic
  ingress_security_rules {
    protocol  = "6"         // tcp
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      "min" = 80
      "max" = 80
    }
  }

  // allow inbound http (port 443) traffic
  ingress_security_rules {
    protocol  = "6"         // tcp
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      "min" = 443
      "max" = 443
    }
  }

  // allow inbound traffic to port 5901 (vnc)
  ingress_security_rules {
    protocol  = "6"         // tcp
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      "min" = 5901
      "max" = 5901
    }
  }

  // allow inbound ssh traffic
  ingress_security_rules {
    protocol  = "6"         // tcp
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      "min" = 22
      "max" = 22
    }
  }

  // allow inbound icmp traffic of a specific type
  ingress_security_rules {
    protocol  = 1
    source    = "0.0.0.0/0"
    stateless = true

    icmp_options {
      "type" = 3
      "code" = 4
    }
  }
}

###############################
## TRUST NETWORK SETTINGS    ##
###############################

resource "oci_core_subnet" "trust_subnet" {
  cidr_block                 = "${var.trust_subnet_cidr}"
  display_name               = "trust"
  compartment_id             = "${var.compartment_ocid}"
  vcn_id                     = "${oci_core_virtual_network.my_vcn.id}"
  route_table_id             = "${oci_core_route_table.trust_routetable.id}"
  security_list_ids          = ["${oci_core_virtual_network.my_vcn.default_security_list_id}", "${oci_core_security_list.trust_security_list.id}"]
  dhcp_options_id            = "${oci_core_virtual_network.my_vcn.default_dhcp_options_id}"
  dns_label                  = "trust"
  prohibit_public_ip_on_vnic = "true"
}

resource "oci_core_route_table" "trust_routetable" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.my_vcn.id}"
  display_name   = "trust-routetable"
}

# Protocols are specified as protocol numbers.
# http://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
resource "oci_core_security_list" "trust_security_list" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.my_vcn.id}"
  display_name   = "trust-security-list"

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }

  // allow outbound udp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "17"        // udp
    stateless   = true
  }

  // allow inbound traffic on all ports from network
  ingress_security_rules {
    protocol  = "6"                          // tcp
    source    = "${var.untrust_subnet_cidr}"
    stateless = false
  }
}


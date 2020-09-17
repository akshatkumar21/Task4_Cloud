provider "aws" {
	region = "ap-south-1"
	profile = "Akshat"
}

resource "aws_vpc" "task4_vpc" {
	cidr_block = "192.170.0.0/16"
	instance_tenancy = "default"
	enable_dns_hostnames= "true"

	tags = {
		Name = "Task4_VPC"
       }
}

resource "aws_subnet" "public_subnet" {
	vpc_id = "${aws_vpc.task4_vpc.id}"
	cidr_block = "192.170.1.0/24"
	availability_zone = "ap-south-1a"
	map_public_ip_on_launch = true

	tags = {
		Name = "Public_Subnet"
       }
}

resource "aws_subnet" "private_subnet" {
	vpc_id = "${aws_vpc.task4_vpc.id}"
	cidr_block = "192.170.2.0/24"
	availability_zone = "ap-south-1b"

	tags = {
		Name = "Private_Subnet"
       }
}

resource "aws_internet_gateway" "task4_internet_gateway" {
	vpc_id = "${aws_vpc.task4_vpc.id}"
	tags = {
		Name = "Task4_internet_gateway"
	}
}

resource "aws_route_table" "task4_route_table" {
  vpc_id = "${aws_vpc.task4_vpc.id}"

    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.task4_internet_gateway.id}"
  }
  
  tags = {
    Name = "Task4_Route_Table"
  }
}

resource "aws_route_table_association" "task4_route_public"{
	subnet_id= aws_subnet.public_subnet.id
	route_table_id = "${aws_route_table.task4_route_table.id}"
}

resource "tls_private_key"  "my_task4_key"{
	algorithm= "RSA"
}

resource  "aws_key_pair"   "generated_key"{
	key_name= "MyTask4Key"
	public_key= "${tls_private_key.my_task4_key.public_key_openssh}"
	
	depends_on = [
		tls_private_key.my_task4_key
		]
}

resource "local_file"  "store_key_value"{
	
	content= "${tls_private_key.my_task4_key.private_key_pem}"
 	filename= "MyTask4Key.pem"
	file_permission= "0400"
	
	depends_on = [
		tls_private_key.my_task4_key
	]
}

resource "aws_security_group"   "wordpress_sg" {
  name        = "WordPress_sg"
  description = "Security Group for Wordpress Website"
  vpc_id      = "${aws_vpc.task4_vpc.id}"


ingress {
    description = "SSH Protocol"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
ingress {
    description = "HTTP Protocol"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
ingress{
    description="ICMP"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks=["0.0.0.0/0"]
  } 


egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

tags = {
    Name = "WordPress_sg"
  }
}

resource "aws_security_group"   "MySQL_sg" {
  name        = "MySQL_sg"
  description = "Security Group for SQL DB"
  vpc_id      = "${aws_vpc.task4_vpc.id}"

ingress {
    description = "SQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups=["${aws_security_group.wordpress_sg.id}"]
  }

egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

tags = {
    Name = "MySQL_sg"
  }
}

resource "aws_security_group"   "bastion_sg" {
  name        = "Bastion_sg"
  description = "Security Group for Bastion Instance"
  vpc_id      = "${aws_vpc.task4_vpc.id}"

ingress {
    description = "SSH Protocol"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

tags = {
    Name = "Bastion_Host_sg"
  }
}

resource "aws_security_group"   "MySQL_connectivity_sg" {
  name        = "MySQL_Connectivity_sg"
  description = "Security Group for Bastion Instance and SQL connectivity"
  vpc_id      = "${aws_vpc.task4_vpc.id}"

ingress {
    description = "SSH Protocol"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups=["${aws_security_group.bastion_sg.id}"]
  }
  
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

tags = {
    Name = "MySQL_Connectivity_sg"
  }
}

resource  "aws_eip"  "task4_eip"{
	vpc= true
}

resource "aws_nat_gateway"   "task4_ng"{
	allocation_id= "${aws_eip.task4_eip.id}"
	subnet_id= "${aws_subnet.public_subnet.id}"

tags = {
	    Name = "Task4_NAT_Gateway"
	}
}

resource "aws_route_table" "task4_routetable_2" {
  vpc_id = "${aws_vpc.task4_vpc.id}"

route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.task4_ng.id}"
  }
  
tags = {
    Name = "Task4_Route_Table2"
  }
}

resource "aws_route_table_association" "task4_route_private"{
  subnet_id= aws_subnet.private_subnet.id
  route_table_id = "${aws_route_table.task4_routetable_2.id}"
}

resource "aws_instance" "wordpress_os"{
	ami= "ami-000cbce3e1b899ebd"
	instance_type= "t2.micro"
	subnet_id= "${aws_subnet.public_subnet.id}"
	vpc_security_group_ids= ["${aws_security_group.wordpress_sg.id}"]
	key_name= "MyTask4Key"
	
tags = {
	     Name = "WordPress_OS"
	}
}

resource "aws_instance"  "sql_os"{
	ami = "ami-08706cb5f68222d09"
	instance_type= "t2.micro"
	subnet_id= "${aws_subnet.private_subnet.id}"
	vpc_security_group_ids=["${aws_security_group.MySQL_sg.id}","${aws_security_group.MySQL_connectivity_sg.id}"]
	  key_name= "MyTask4Key"
	
	tags = {
	        Name="MySQL_OS"
	}
}

resource "aws_instance"  "bastion_os"{
	ami = "ami-0732b62d310b80e97"
	instance_type="t2.micro"
	subnet_id= "${aws_subnet.public_subnet.id}"
	vpc_security_group_ids= ["${aws_security_group.bastion_sg.id}"]
	key_name="MyTask4Key"
	
	tags={
	    Name= "Bastion_Host_OS"
	}
}

output "mywordpressos_ip" {
  value = aws_instance.wordpress_os.public_ip
}


output "mysqlOSPrivate_ip" {
  value = aws_instance.sql_os.private_ip
}


output "bastionos_ip" {
  value = aws_instance.bastion_os.public_ip
}
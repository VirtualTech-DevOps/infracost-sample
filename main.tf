locals {
  cidr_block = "10.0.0.0/16"
}

resource "aws_vpc" "this" {
  cidr_block = local.cidr_block
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  for_each = toset(data.aws_availability_zones.available.names)

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(local.cidr_block, 8, index(tolist(toset(data.aws_availability_zones.available.names)), each.key))
}

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  for_each = toset(data.aws_availability_zones.available.names)

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(local.cidr_block, 8, index(tolist(toset(data.aws_availability_zones.available.names)), each.key) + length(aws_subnet.public))
}

resource "aws_eip" "nat_gateway" {}

resource "aws_nat_gateway" "private" {
  subnet_id     = aws_subnet.public[data.aws_availability_zones.available.names[0]].id
  allocation_id = aws_eip.nat_gateway.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private.id
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "random_integer" "public_subnet_key" {
  min = 0
  max = length(aws_subnet.public) - 1
}

resource "random_integer" "private_subnet_key" {
  min = 0
  max = length(aws_subnet.private) - 1
}

data "aws_ami" "amazonlinux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp3"]
  }
}

resource "aws_instance" "public" {
  ami           = data.aws_ami.amazonlinux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[random_integer.public_subnet_key.result].id

  tags = {
    Name = "demo-public"
  }
}

resource "aws_instance" "private" {
  ami           = data.aws_ami.amazonlinux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[random_integer.private_subnet_key.result].id

  tags = {
    Name = "demo-public"
  }
}

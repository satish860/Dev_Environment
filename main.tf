resource "aws_vpc" "mainvpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.mainvpc.id
  cidr_block              = "10.1.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.mainvpc.id
  tags = {
    Name = "dev-ig"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mainvpc.id

  tags = {
    Name = "dev-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.mainvpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "authkey"
  public_key = file("~/.ssh/key.pub")
}

resource "aws_instance" "devnode" {
  ami                    = data.aws_ami.server_ami.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.auth.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.main.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "devnode"
  }

  provisioner "local-exec" {
    command = templatefile("windows.ssh.config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      Identityfile = "~/.ssh/key"
    })
    interpreter = ["Powershell -Command"]
  }
}


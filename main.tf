terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.38.0"
    }
  }

    cloud {
      organization = "yannis-bhm"

      workspaces {
        name = "livecode"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}



resource "aws_instance" "web-server-instance" {
  ami               = "ami-05262a4bcea6f9fa2"
  instance_type     = "t2.micro"

  user_data = "${file("install.sh")}"
  user_data_replace_on_change = true

  tags = {
    Name = "yannis-server"
  }

}

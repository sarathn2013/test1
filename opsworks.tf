# Specify AWS provider and access details
provider "aws" {
 access_key = "${var.access_key}"
 secret_key = "${var.secret_key}" 
 region = "us-east-2"
}

# Uploading keypairs into aws
resource "aws_key_pair" "mykeypair" {
  key_name = "mykeypair"
  public_key = "${file("${var.PATH_TO_PUBLIC_KEY}")}"
}


variable "PATH_TO_PRIVATE_KEY" {
  default = "mykey"

}

variable "PATH_TO_PUBLIC_KEY" {
  default = "mykey.pub"

}


# Creating IAM Role Policy
resource "aws_iam_role_policy" "opsworks" {
  name = "opsworks-role-policy"
  role = "${aws_iam_role.opsworks.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
   "Statement": [
        {
            "Action": [
                "ec2:*",
                "iam:PassRole",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:DescribeAlarms",
                "ecs:*",
                "elasticloadbalancing:*",
                "rds:*"
            ],
            "Effect": "Allow",
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}


# Creating IAM Role for opsworks
resource "aws_iam_role" "opsworks" {
  name = "test_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
               "Service": "opsworks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"            
        }
    ]
}
EOF
} 

# creating IAM profile
resource "aws_iam_instance_profile" "opsworks1" {
  name  = "opsworks1"
  role = "${aws_iam_role.opsworks.name}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "abc-vpc" {  
  cidr_block = "10.0.0.0/16"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "abc-web-subnet" {
  vpc_id                  = "${aws_vpc.abc-vpc.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
}


#  Creating internet gateway for primary vpc
 resource "aws_internet_gateway" "abc-vpc-igw" {
    vpc_id = "${aws_vpc.abc-vpc.id}"

    tags {
        Name = "abc-vpc-igw"
    }
 }



# Creating route table for  subnet
 resource "aws_route_table" "abc-vpc-route" {
   vpc_id = "${aws_vpc.abc-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.abc-vpc-igw.id}"
    }
    tags {
        Name = "abc-vpc-route"
    }
 }



# route associations for secondary vpc public subnet
resource "aws_route_table_association" "abc-subnet" {
    subnet_id = "${aws_subnet.abc-web-subnet.id}"
    route_table_id = "${aws_route_table.abc-vpc-route.id}"
}


# Creating  AWS OpsWorks Stack
resource "aws_opsworks_stack" "main" {
   name = "abc-stack"
   region = "us-east-2"
   use_custom_cookbooks = true
   custom_cookbooks_source {
   url = "https://s3.us-east-2.amazonaws.com/o0oio/opsworks-cookbooks.tar.gz"
   type = "s3"
   }
   service_role_arn             = "${aws_iam_role.opsworks.arn}"
   default_instance_profile_arn = "${aws_iam_instance_profile.opsworks1.arn}"
   vpc_id                       = "${aws_vpc.abc-vpc.id}"
   default_subnet_id            = "${aws_subnet.abc-web-subnet.id}"
 }

# Create layer inside opsworks stack
resource "aws_opsworks_custom_layer" "test-layer" {
  name     =   "test-layer"
  short_name = "testapp"
  stack_id = "${aws_opsworks_stack.main.id}"  
}


# Create App in the opsworks stack
resource "aws_opsworks_application" "testapp" {
  name        = "testapp"
  short_name  = "testapp"
  stack_id    = "${aws_opsworks_stack.main.id}"
  type        = "rails"
  description = "This is a Rails application"

#  domains = [
#    "example.com",
#    "sub.example.com",
#  ]

  environment = {
    key    = "key"
    value  = "value"
    secure = true
  }

  app_source = {
    type     = "git"
    revision = "master"
    url      = "https://github.com/sarathn2013/alpha_blog.git"
  }

#  enable_ssl = true

#  ssl_configuration = {
#    private_key = "${file("./foobar.key")}"
#    certificate = "${file("./foobar.crt")}"
#  }

  document_root         = "public"
  auto_bundle_on_deploy = true
  rails_env             = "staging"
}


resource "aws_eip" "test-instance-ip" {
   vpc = true
}





# Creating ec2 instance for this stack.

 resource "aws_opsworks_instance" "test-instance" {
   stack_id = "${aws_opsworks_stack.main.id}"

  layer_ids = [
    "${aws_opsworks_custom_layer.test-layer.id}",
  ]
  ssh_key_name = "${aws_key_pair.mykeypair.key_name}"
  subnet_id  = "${aws_subnet.abc-web-subnet.id}"
  instance_type = "t2.micro"
  public_ip     = "${aws_eip.test-instance-ip.ip}"
  ami_id        = "ami-618fab04"
  state         = "running"

}




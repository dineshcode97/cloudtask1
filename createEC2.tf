//To Tell Terraform Which Cloud We Want To Use
provider "aws" {
region   = "ap-south-1"
profile  = "dinesh97"
}


//Use RSA Algorithm For Key
resource "tls_private_key" "terraos_key" {
  algorithm = "RSA"
}


//Create a Key 
resource "aws_key_pair" "deployment_key" {
  key_name   = "terraos_key"
  public_key = "${tls_private_key.terraos_key.public_key_openssh}"


  depends_on = [
    tls_private_key.terraos_key
  ]
}


//Saving The Key In Local System
resource "local_file" "key-file" {
  content  = "${tls_private_key.terraos_key.private_key_pem}"
  filename = "terraoskey.pem"


  depends_on = [
    tls_private_key.terraos_key
  ]
}


//Creating A New Security Group
resource "aws_security_group" "http_request" {
  name        = "http_request"
  description = "Allow TCP inbound traffic"
  vpc_id      = "vpc-691b0401"

  //Allowing http port
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 //Allowing SSH port
 ingress {
    description = "SSH from VPC"
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
    Name = "http_request"
  }
}


//Creting An EC2 Instance
resource "aws_instance" "myterraos" {
	ami            =  "ami-0447a12f28fddb066"
	instance_type  =  "t2.micro"
	key_name       =  aws_key_pair.deployment_key.key_name
	security_groups = ["http_request"]
	
	connection {
	  type     = "ssh"
	  user     = "ec2-user"
	  private_key = "${tls_private_key.terraos_key.private_key_pem}"
	  host     = aws_instance.myterraos.public_ip
	  }

	  provisioner "remote-exec" {
	    inline = [
	      "sudo yum install httpd  php git -y",
	      "sudo systemctl restart httpd",
	      "sudo systemctl enable httpd"
	    ]
	}
	tags = {
	Name = "myterraos"
	}
}


//Creating an EBS Volume
resource "aws_ebs_volume" "myebsvol1" {
  availability_zone = aws_instance.myterraos.availability_zone
  size = 1

  tags = {
    Name = "myebsvol1"
  }
}


//Attaching an EBS Volume to EC2
resource "aws_volume_attachment" "myebs_attach" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.myebsvol1.id
  instance_id = aws_instance.myterraos.id
  force_detach = true
}


//Null Resource Which Run After Attaching EBS Volume
resource "null_resource" "remote1"  {

//depends_on: used to run the block
//after a specified block 

depends_on = [
    aws_volume_attachment.myebs_attach,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.terraos_key.private_key_pem}"
    host     = aws_instance.myterraos.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdd",
      "sudo mount  /dev/xvdd  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/dineshcode97/cloudtask1.git /var/www/html/"
    ]
  }
}


//Printing EC2 Instance IP
output "myterraos_ip" {
	value = aws_instance.myterraos.public_ip
}

//Saving IP in a text file
resource "null_resource" "local1"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.myterraos.public_ip} > publicip.txt"
  	}
}

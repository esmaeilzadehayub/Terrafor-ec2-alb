resource "aws_key_pair" "deployer" {     # Creating the Key pair on AWS 
  key_name   = "deployer-key"
  public_key = "${file("~/.ssh/id_rsa.pub")}" # Generated private and public key on local machine
}
resource "aws_instance" "my-machine" {
  count = 2    # Here we are creating identical 4 machines.
  
  ami = var.ami
  instance_type = var.instance_type
  key_name = aws_key_pair.deployer.key_name
  tags = {
    Name = "my-machine-${count.index}"
         }
 provisioner  "remote-exec" {            # Provisioner 2 [needs SSH/Winrm connection]
      connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      agent       = false
      host        = aws_instance.my-machine.public_ip       # Using my instance to connect
      timeout     = "30s"
    }
      inline = [
        "sudo apt install -y python",
        "sudo apt install ansible -y",
        
      ]
  }
   provisioner "file" {                    # Provisioner 3 [needs SSH/Winrm connection]
    source      = "*.yml"
    destination = "/tmp/file.json"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.my-machine.public_ip
      private_key = "${file("~/.ssh/id_rsa")}"
      agent       = false
      timeout     = "30s"
    }
  }  
}
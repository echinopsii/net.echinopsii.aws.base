variable "ami_basenames" {
    type = "map"
    default = {
        "debian-8.4" = "debian-jessie-amd64-hvm*"
        "ubuntu-16.04:eu-west-1" = "ubuntu/images-milestone/hvm-ssd/ubuntu-xenial-16.04*"
    }
}

variable "root_device" {
    default = {
        "debian" = "/dev/xvda"
        "ubuntu" = "/dev/sda1"
        "rhel" = "/dev/sda1"
    }
}

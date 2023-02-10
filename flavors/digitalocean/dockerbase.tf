variable "jwt_secret" {
    default = ""
}

variable "minio_access_key" {
   default = ""
}

variable "minio_secret_key" { 
   default = ""
}

variable "couch_db_password" { 
   default = ""
}

variable "couch_db_user" { 
   default = ""
}

variable "redis_password" { 
   default = ""
}

variable "internal_api_key" { 
   default = ""
}

variable "domain" {
    default = ""
}

variable "webmaster_email" {
    default = ""
}

resource "random_password" "jwt_secret" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "minio_access_key" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "minio_secret_key" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "couch_db_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "couch_db_user" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "redis_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "internal_api_key" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "digitalocean_droplet" "www-budibase" {
  #This has pre installed docker
  image = "docker-20-04"
  name = "www-budibase"
  region = "nyc3"
  size = "s-1vcpu-1gb"
  ssh_keys = [
    digitalocean_ssh_key.terraform.id
  ]

  connection {
    host = self.ipv4_address
    user = "root"
    type = "ssh"
    private_key = var.pvt_key != "" ? file(var.pvt_key) : tls_private_key.pk.private_key_pem
    timeout = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      # install nginx and docker
      "sleep 5s",
      "apt update",
      "sleep 5s",
      "apt install -y nginx",
      "apt install -y python3-certbot-nginx",
      "apt install -y docker-compose",
      # create nocodb installation directory
      "mkdir /root/budibase",
    ]
  }

  provisioner "file" {
    source      = "docker-compose.yml.tpl"
    destination = "/root/budibase/docker-compose.yml"
  }

  provisioner "file" {
    content      = templatefile("atmosphere-nginx.conf.tpl", {
      server_name = var.domain != "" ? var.domain : "0.0.0.0"
    })
    destination = "/etc/nginx/conf.d/atmosphere-nginx.conf"
  }

  provisioner "file" {
    content      = templatefile("env-production.tpl", {
      jwt_secret = var.jwt_secret != "" ? var.jwt_secret : random_password.jwt_secret.result,
      minio_access_key = var.minio_access_key != "" ? var.minio_access_key : random_password.jwt_secret.result,
      minio_secret_key = var.minio_secret_key != "" ? var.minio_secret_key : random_password.minio_secret_key.result,
      couch_db_password = var.couch_db_password != "" ? var.couch_db_password : random_password.couch_db_password.result,
      couch_db_user = var.couch_db_user != "" ? var.couch_db_user : random_password.couch_db_user.result,
      redis_password = var.redis_password != "" ? var.redis_password : random_password.redis_password.result,
      internal_api_key = var.internal_api_key != "" ? var.internal_api_key : random_password.internal_api_key.result,
    })
    destination = "/root/budibase/.env"
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      # run compose
      "cd /root/budibase",
      "docker-compose up -d",
      "rm /etc/nginx/sites-enabled/default",
      "systemctl restart nginx",
      "ufw allow http",
      "ufw allow https",
      "%{if var.domain!= ""}certbot --nginx --non-interactive --agree-tos --domains ${var.domain} --redirect %{if var.webmaster_email!= ""} --email ${var.webmaster_email} %{ else } --register-unsafely-without-email %{ endif } %{ else }echo NOCERTBOT%{ endif }"
    ]
  }
}

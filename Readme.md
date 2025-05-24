# AWS Auto Scaling Demo with Terraform

Este proyecto contiene un ejemplo básico de infraestructura en AWS utilizando **Terraform**, diseñado para demostrar el funcionamiento de **autoescalado (autoscaling)** y **elasticidad** de recursos mediante alarmas y políticas de escalado basadas en el uso de CPU.

## 🚀 Requisitos

Antes de comenzar, asegúrate de tener instalado:

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- Una cuenta de AWS con credenciales configuradas (`aws configure`)

---

## ⚙️ Despliegue


1. Clona el repositorio:
   ```bash
   git clone https://github.com/Nyanzey/AutoscalingDemo.git
   cd AutoscalingDemo
   ```



2. Inicializa el proyecto de Terraform:

   ```bash
   terraform init
   ```



3. Aplica la configuración (esto creará los recursos en AWS):

   ```bash
   terraform apply
   ```

   Confirma con `yes` cuando se te solicite.

---

## 🌐 Acceso a la aplicación

Una vez desplegado, accede a la aplicación a través del **DNS del Load Balancer** que se mostrará en la salida del `terraform apply`.

---

## 🧹 Eliminación de recursos

Para evitar cargos en tu cuenta de AWS, destruye los recursos al terminar:

```bash
terraform destroy
```
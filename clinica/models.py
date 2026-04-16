from django.db import models
from django.core.validators import RegexValidator


class Paciente(models.Model):
    nombre = models.CharField(max_length=150)
    cedula = models.CharField(
        max_length=20,
        unique=True,
        validators=[
            RegexValidator(
                regex=r"^\d+$",
                message="La cédula debe contener solo números.",
            )
        ],
    )
    telefono = models.CharField(
        max_length=20,
        validators=[
            RegexValidator(
                regex=r"^\+?\d+$",
                message="El teléfono debe contener solo números.",
            )
        ],
    )
    email = models.EmailField()

    def __str__(self):
        return f"{self.nombre} ({self.cedula})"


class Cita(models.Model):
    paciente = models.ForeignKey(Paciente, on_delete=models.CASCADE)
    fecha = models.DateTimeField()
    motivo = models.TextField()

    def __str__(self):
        return f"{self.paciente.nombre} - {self.fecha:%Y-%m-%d %H:%M}"

from django import forms
from django.utils import timezone

from .models import Cita, Paciente


class PacienteForm(forms.ModelForm):
    class Meta:
        model = Paciente
        fields = "__all__"
        widgets = {
            "nombre": forms.TextInput(attrs={"class": "form-control"}),
            "cedula": forms.TextInput(attrs={"class": "form-control"}),
            "telefono": forms.TextInput(attrs={"class": "form-control"}),
            "email": forms.EmailInput(attrs={"class": "form-control"}),
        }


class CitaForm(forms.ModelForm):
    class Meta:
        model = Cita
        fields = "__all__"
        widgets = {
            "paciente": forms.Select(attrs={"class": "form-control"}),
            "fecha": forms.DateTimeInput(
                attrs={"class": "form-control", "type": "datetime-local"}
            ),
            "motivo": forms.Textarea(attrs={"class": "form-control"}),
        }

    def clean_fecha(self):
        fecha = self.cleaned_data["fecha"]
        if fecha < timezone.now():
            raise forms.ValidationError("No se puede programar una cita en el pasado.")
        return fecha

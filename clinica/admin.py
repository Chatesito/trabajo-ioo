from django.contrib import admin
from .models import Cita, Paciente

admin.site.register(Paciente)
admin.site.register(Cita)

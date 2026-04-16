from django.urls import path

from .views import (
    CitaCreateView,
    CitaDeleteView,
    CitaListView,
    CitaUpdateView,
    PacienteCreateView,
    PacienteDeleteView,
    PacienteListView,
    PacienteUpdateView,
)

urlpatterns = [
    path("pacientes/", PacienteListView.as_view(), name="paciente_list"),
    path("pacientes/nuevo/", PacienteCreateView.as_view(), name="paciente_create"),
    path("pacientes/<int:pk>/editar/", PacienteUpdateView.as_view(), name="paciente_update"),
    path("pacientes/<int:pk>/eliminar/", PacienteDeleteView.as_view(), name="paciente_delete"),
    path("citas/", CitaListView.as_view(), name="cita_list"),
    path("citas/nueva/", CitaCreateView.as_view(), name="cita_create"),
    path("citas/<int:pk>/editar/", CitaUpdateView.as_view(), name="cita_update"),
    path("citas/<int:pk>/eliminar/", CitaDeleteView.as_view(), name="cita_delete"),
]

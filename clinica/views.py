from django.urls import reverse_lazy
from django.views.generic import CreateView, DeleteView, ListView, UpdateView

from .forms import CitaForm, PacienteForm
from .models import Cita, Paciente


class PacienteListView(ListView):
    model = Paciente


class PacienteCreateView(CreateView):
    model = Paciente
    form_class = PacienteForm
    success_url = reverse_lazy("paciente_list")


class PacienteUpdateView(UpdateView):
    model = Paciente
    form_class = PacienteForm
    success_url = reverse_lazy("paciente_list")


class PacienteDeleteView(DeleteView):
    model = Paciente
    success_url = reverse_lazy("paciente_list")


class CitaListView(ListView):
    model = Cita

    def get_queryset(self):
        return Cita.objects.select_related("paciente").all()


class CitaCreateView(CreateView):
    model = Cita
    form_class = CitaForm
    success_url = reverse_lazy("cita_list")


class CitaUpdateView(UpdateView):
    model = Cita
    form_class = CitaForm
    success_url = reverse_lazy("cita_list")


class CitaDeleteView(DeleteView):
    model = Cita
    success_url = reverse_lazy("cita_list")

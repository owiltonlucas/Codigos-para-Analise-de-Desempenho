import numpy as np
import matplotlib.pyplot as plt
import scipy.stats as stats

# Dados coletados

mspt_data = {
    "5s": [1.6, 1.9, 1.4, 1.8, 1.6, 1.8, 2.3, 0.6, 0.5, 1.8],
    "10s": [0.8, 0.9, 1.2, 0.9, 1.1, 0.9, 1.1, 0.8, 0.5, 0.9],
    "1m": [0.1, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2]
}

cpu_usage = [71.4, 48.8, 37.1, 30.3, 72.6, 49.3, 37.4, 30.4, 72.9, 49.8, 37.8, 30.8]
ram_usage = [1644, 1647, 1647, 1652, 1645, 1648, 1648, 1650, 1603, 1607, 1607, 1607]
disk_usage = [37, 37, 37, 37, 37, 37, 37, 37, 37, 37, 37, 37]
latency = [0.019, 0.016, 0.015, 0.071, 0.015, 0.016, 0.017, 0.014, 0.015, 0.016, 0.016, 0.017]

# Função para calcular média e intervalo de confiança (95%)
def calcular_ic(data):
    n = len(data)
    media = np.mean(data)
    desvio_padrao = np.std(data, ddof=1)  # ddof=1 para amostra
    erro = stats.t.ppf(0.975, n-1) * (desvio_padrao / np.sqrt(n))
    return media, erro

# Calcular para mspt
mspt_medias = []
mspt_erros = []
labels_mspt = ["5s", "10s", "1m"]
for key in mspt_data:
    media, erro = calcular_ic(mspt_data[key])
    mspt_medias.append(media)
    mspt_erros.append(erro)

# Calcular para outras métricas
cpu_media, cpu_erro = calcular_ic(cpu_usage)
ram_media, ram_erro = calcular_ic(ram_usage)
disk_media, disk_erro = calcular_ic(disk_usage)
latency_media, latency_erro = calcular_ic(latency)

# Criando os gráficos
fig, axs = plt.subplots(2, 2, figsize=(12, 10))

# Gráfico 1: mspt com IC 95%
axs[0, 0].errorbar(labels_mspt, mspt_medias, yerr=mspt_erros, fmt='o-', capsize=5, color='blue')
axs[0, 0].set_title('Média mspt com IC 95%')
#axs[0, 0].set_xlabel('Intervalo de Tempo')
axs[0, 0].set_ylabel('mspt (ms)')

# Gráfico 2: Uso de CPU com IC 95%
axs[0, 1].bar(["CPU"], [cpu_media], yerr=[cpu_erro], capsize=5, color='skyblue')
axs[0, 1].set_title('Uso da CPU (%) com IC 95%')
axs[0, 1].set_ylabel('CPU (%)')

# Gráfico 3: Uso de RAM com IC 95%
axs[1, 0].bar(["RAM"], [ram_media], yerr=[ram_erro], capsize=5, color='salmon')
axs[1, 0].set_title('Uso de RAM (MB) com IC 95%')
axs[1, 0].set_ylabel('RAM (MB)')
axs[1, 0].set_ylim(0, 2000)  # Definindo o limite máximo do eixo Y para 2GB (2000 MB)

# Gráfico 4: Latência com IC 95%
axs[1, 1].bar(["Latência"], [latency_media], yerr=[latency_erro], capsize=5, color='violet')
axs[1, 1].set_title('Latência (s) com IC 95%')
axs[1, 1].set_ylabel('Latência (s)')

plt.tight_layout()
plt.show()

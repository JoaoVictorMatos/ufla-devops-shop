# Autopsia: GitLab.com - saida por perda de banco de dados (31/01/2017)

**Autor:** Joao Victor Matos (@JoaoVictorMatos)
**Fonte primaria:** https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/
**Data de acesso:** 29/08/2026

## 1. O que aconteceu

No dia 31/01/2017, por volta das 23h30 (UTC), um engenheiro do GitLab tentava
reconstruir a replicacao do banco de dados e apagou por engano a pasta de
dados do servidor principal, em uso pelos clientes, pensando que estava
apagando a do servidor de reserva. Ele interrompeu o comando poucos segundos
depois de perceber o erro, mas cerca de 300 GB ja tinham sido removidos. O
site GitLab.com ficou fora do ar por cerca de 18 horas, ate por volta das 18h
de 01/02. Dados criados entre 17h20 e 23h30 do dia 31/01 foram perdidos de
forma definitiva - cerca de 5 mil projetos, 5 mil comentarios e 700 contas de
usuario. Dos cinco mecanismos de backup e replicacao que a empresa mantinha,
nenhum permitiu restaurar esses dados.

## 2. Qual das Tres Vias falhou

**Feedback.** O comando errado foi apenas o gatilho; o que permitiu o
desastre foi a ausencia de retroalimentacao sobre um problema que ja existia
havia meses. O backup diario feito com `pg_dump` vinha falhando silenciosamente
porque rodava com uma versao do PostgreSQL incompativel com a do banco de
producao. Os avisos de erro do cronjob eram enviados por e-mail, mas esses
e-mails eram rejeitados pelo servidor de destino porque o DMARC nao estava
configurado para eles - "this means we were never aware of the backups
failing, until it was too late". Um sinal que deveria ter voltado rapido para
o time levou meses para ser percebido, e so apareceu no pior momento possivel.

## 3. Quais metricas DORA denunciariam antes

**Change Failure Rate** e **Time to Restore Service.** O proprio relatorio
lista, antes do incidente, uma sequencia de problemas recorrentes no mesmo
par de servidores (a saida de novembro de 2016 por excesso de bloat em
`project_authorizations`, travamentos causados por polling distribuido do CI
e os "Scary DB spikes" citados por nome) - ou seja, uma taxa de falha por
mudanca ja elevada e concentrada num unico ponto critico (`db1.cluster.gitlab.com`)
bem antes de 31/01. Quanto ao MTTR, o relatorio explica que o procedimento de
restauracao nunca tinha sido testado de ponta a ponta porque "there was no
ownership, as a result nobody was responsible for testing this procedure".
Sem ensaios de restauracao, a organizacao nao tinha um MTTR real medido - ele
so foi descoberto (em 18 horas, no melhor cenario disponivel) durante o
proprio incidente.

## 4. Qual pratica do semestre teria evitado - e em que semana

Instrumentacao e monitoramento com alertas ativos - **semana 13** do nosso
roadmap, quando a aplicacao passa a ter metricas RED no Prometheus, paineis
no Grafana e definicao de SLO. O problema da GitLab nao era falta de backup
agendado (isso ja existia desde a semana 3-4 do roadmap, quando o backup
agendado entra junto com o processo gerenciado por `systemd`); era a
ausencia de um canal de alerta confiavel para quando esse backup falhasse. Um
SLO explicito do tipo "existe um backup valido das ultimas 24h", com alerta
disparado pelo Prometheus/Grafana quando o job de `pg_dump` termina com erro,
nao dependeria de um unico e-mail podendo ser rejeitado por DMARC mal
configurado - o time teria sido avisado da incompatibilidade de versao do
PostgreSQL meses antes, e nao apenas no momento em que precisou do backup de
verdade.

## 5. A cultura do relatorio: generativa ou patologica?

**Generativa.** O texto descreve o problema em termos de sistema, nao de
pessoa: fala em processos que faltavam, documentacao que nao existia e
verificacoes automaticas ausentes, nunca em um funcionario incompetente. O
CEO assume responsabilidade publicamente ("I apologize personally, as
GitLab's CEO, and on behalf of everyone at GitLab"), a empresa transmitiu a
recuperacao ao vivo no YouTube e manteve um documento publico com o andamento
em tempo real, e a frase que resume a cultura pretendida aparece no proprio
relatorio: "An ideal environment is one in which you can make mistakes but
easily and quickly recover from them with minimal to no impact." Essa e
exatamente a definicao de cultura generativa de Westrum: a falha vira gatilho
de investigacao e melhoria do sistema, nao de punicao de quem apertou o
comando.

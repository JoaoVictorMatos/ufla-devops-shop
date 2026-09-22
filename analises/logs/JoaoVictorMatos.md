# Analise de access.log -- Joao Victor Matos (@JoaoVictorMatos)

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
awk '{ t++; if ($9 ~ /^4/) q4++; else if ($9 ~ /^5/) q5++ }
     END { printf "total %d\n4xx   %d (%.2f%%)\n5xx   %d (%.2f%%)\n",
                  t, q4, q4*100/t, q5, q5*100/t }' dados/access.log
```
```
total 516866
4xx   6162 (1.19%)
5xx   11749 (2.27%)
```
**Leitura:** de cada 100 requisicoes, cerca de 3,5 terminam em erro (1,19% em 4xx, 2,27% em
5xx). A falha do servidor (5xx) e quase o dobro da falha do cliente (4xx), o que aponta para
um problema do lado de dentro, e nao para usuarios errando URL.

## 2. Os 10 IPs mais frequentes

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10
```
```
  88400 203.0.113.47
   1788 192.0.2.245
   1772 192.0.2.171
   1771 192.0.2.81
   1771 192.0.2.225
   1771 192.0.2.16
   1767 192.0.2.138
   1762 192.0.2.222
   1757 192.0.2.45
   1753 192.0.2.166
```
**Leitura:** o segundo IP mais frequente tem 1788 requisicoes; o primeiro tem 88400 -- quase
50 vezes mais. Isso sozinho ja e suspeito, mas a regra do enunciado e nao parar na contagem.

Investigando o IP `203.0.113.47`: o que ele pedia, em que ritmo e com que user-agent.

```bash
awk -v ip=203.0.113.47 '$1==ip {print $7}' dados/access.log | sort | uniq -c | sort -rn | head
```
```
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenis
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fone
```
```bash
awk -v ip=203.0.113.47 '$1==ip {print substr($4,2,17)}' dados/access.log | sort | uniq -c | sort -rn | head
```
```
   1021 14/Aug/2026:23:44
   1017 14/Aug/2026:23:00
   1015 14/Aug/2026:23:32
   1007 14/Aug/2026:23:21
   1002 14/Aug/2026:23:17
    995 14/Aug/2026:23:53
    994 14/Aug/2026:23:33
    993 14/Aug/2026:23:28
    992 14/Aug/2026:23:55
    991 14/Aug/2026:23:22
```
```bash
awk -v ip=203.0.113.47 '$1==ip' dados/access.log | grep -o '"[^"]*"$' | sort | uniq -c | sort -rn
```
```
  88400 "curl/8.5.0"
```
```bash
awk -v ip=203.0.113.47 '$1==ip {print $9}' dados/access.log | sort | uniq -c | sort -rn
```
```
  81500 200
   6900 503
```
**Leitura:** sim, e suspeito -- e por sinal contundente, nao por volume isolado. O IP so
bate em `/api/busca` com quatro termos fixos, usa `curl/8.5.0` como user-agent (nenhum
navegador real se apresenta assim) e mantem cerca de 1000 requisicoes por minuto de forma
sustentada, concentrado na hora 23. Isso e uma varredura automatizada em `/api/busca`, nao
trafego de cliente, e e responsavel por 6900 dos 11749 erros 5xx do log inteiro (59%).

## 3. O endpoint quebrado

```bash
awk '$9==500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -10
```
```
   3620 /api/relatorio/gerar
    228 /
    167 /api/produtos
    160 /produtos
    150 /produtos/detalhe
    117 /static/app.css
    105 /static/app.js
     92 /api/carrinho
     63 /api/busca
     44 /favicon.ico
```
```bash
awk -v p=/api/relatorio/gerar '$7==p { t++; if ($9==500) e++ }
     END { printf "%s  total=%d  500=%d  (%.1f%%)\n", p, t, e, e*100/t }' dados/access.log
```
```
/api/relatorio/gerar  total=10400  500=3620  (34.8%)
```
**Leitura:** `/api/relatorio/gerar` disparou na frente com 3620 erros 500, dez vezes mais
que o segundo colocado. Nao quebra sempre: das 10400 vezes que foi chamado, 34,8% terminaram
em 500 -- ou seja, a maioria das chamadas funciona, mas mais de uma em cada tres falha. E
comportamento tipico de instabilidade sob carga ou de um recurso (memoria, timeout,
dependencia externa) que se esgota em parte das execucoes, e nao um bug que quebra 100% das
vezes.

## 4. A hora do pico

```bash
awk '{ split($4, a, ":"); print a[2] }' dados/access.log | sort | uniq -c | sort -k2,2
```
```
   3262 00
   1967 01
   1810 02
   1471 03
   1498 04
   1844 05
   3904 06
   9759 07
  19519 08
  27621 09
  30869 10
  32526 11
  31895 12
  29952 13
  31225 14
  32529 15
  30886 16
  28575 17
  25996 18
  22807 19
  18860 20
  15577 21
  43979 22
  68535 23
```
**Leitura:** o trafego cresce ao longo da manha, fica alto e estavel (27 a 32 mil
requisicoes/hora) do meio-dia ate o fim da tarde, cai a noite -- e depois dispara nas horas
22 e 23, com pico de 68535 na hora 23. Esse pico noturno nao e trafego organico: e a mesma
janela em que o IP `203.0.113.47` concentrou a varredura em `/api/busca` (pergunta 2), o que
explica o salto fora do padrao do resto do dia.

## 5. Alguem batendo na porta

```bash
awk 'tolower($7) ~ /(\/admin|\.env|\.git|wp-login|phpmyadmin)/ {
       n++; ips[$1]; st[$9]++ }
     END { printf "tentativas: %d\nIPs distintos: %d\n", n, length(ips);
           for (s in st) printf "  status %s -> %d\n", s, st[s] }' dados/access.log
```
```
tentativas: 2080
IPs distintos: 2
  status 404 -> 2080
```
**Leitura:** 2080 tentativas de acessar caminho sensivel, vindas de apenas 2 IPs
(`198.51.100.9` e `198.51.100.23`, cerca de 1000 cada), alvejando `/admin`, `/admin/login`,
`/wp-login.php`, `/.git/config`, `/.env` e `/phpmyadmin/index.php`. O servidor respondeu 404
a todas -- nenhuma dessas rotas existe de fato na aplicacao -- entao e uma varredura
automatizada de vulnerabilidades comuns que, por ora, nao encontrou nada para explorar.

## Conclusao: minha primeira acao como operador de plantao

Se eu fosse o operador de plantao nesta madrugada, a primeira acao concreta seria bloquear
(rate-limit ou block direto no proxy/WAF) o IP `203.0.113.47`. Ele e o unico problema dos
cinco que esta causando dano em tempo real: sozinho respondeu por 88400 das 516866
requisicoes do log (17%) e por 6900 dos 11749 erros 5xx (59% de toda a falha 5xx do
periodo), tudo concentrado exatamente na hora de maior trafego (23h), disputando capacidade
do servidor com clientes de verdade e provocando os 503 que aparecem no meio disso. Os
outros achados pedem acao, mas nao agora: `/api/relatorio/gerar` (pergunta 3) e um bug para
escalar ao time responsavel pelo endpoint, e as varreduras em `/admin`, `.env` e `.git`
(pergunta 5) ja estao sendo bloqueadas pelo proprio 404 e servem para abrir um alerta de
monitoramento, nao para uma acao imediata. Bloquear o scraper e a unica das cinco coisas que
para uma degradacao que esta acontecendo agora.

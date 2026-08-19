# João Victor Matos

- **GitHub:** @JoaoVictorMatos
- **Curso e periodo:** Sistemas de Informação
- **Linguagem que voce domina melhor:** TypeScript
- **Ja usou Linux no dia a dia?** sim
- **Ja usou Docker?** sim
- **O que voce espera desta disciplina:** Espero aprender o necessário para começar minha especialização em DevSecOps.

## Parte B — Diagnóstico DORA do seu último projeto

| Métrica | Resposta |
|---|---|
| Frequência de implantação | O projeto (um sistema de contabilidade automatizada para a empresa onde trabalho, na Flórida/EUA) foi para produção nesta semana. |
| Lead time para mudanças | No máximo 1 dia entre escrever o código e ele estar disponível para o usuário. |
| Tempo de restauração | Em média 1 dia para voltar a funcionar quando algo quebrava. |
| Taxa de falha em mudanças | Cerca de 7 a cada 10 entregas quebraram algo que antes funcionava. |

A métrica mais problemática do meu projeto foi a **taxa de falha em mudanças**: aproximadamente 7 a cada 10 entregas quebravam algo que já funcionava. A causa principal era a diferença entre o ambiente de teste e o ambiente de produção — o que passava nos testes locais frequentemente se comportava de forma diferente (ou falhava) quando ia para produção, já que as configurações, dados e integrações não eram equivalentes entre os dois ambientes.

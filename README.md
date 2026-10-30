# Radar de Notícias com IA

Clipping automático de notícias com **n8n** e **agentes de IA**. Duas vezes por dia, o fluxo busca notícias sobre um tema, filtra, classifica e resume, e entrega um relatório no Telegram e no e-mail.

> 🚧 **Projeto em construção.** O README é atualizado ao fim de cada fase.

## O problema

Na assessoria de imprensa, o clipping (procurar, ler e organizar as notícias sobre um cliente e conferir se elas trazem as mensagens-chave dele) é feito à mão e leva de 30 minutos a 1 hora por dia. Além do tempo, sempre existe o risco de deixar alguma notícia passar. Este projeto automatiza esse trabalho.

## Status

| Fase | O que entrega | Status |
|---|---|---|
| 0. Ambiente | Estrutura do repositório, proteção de segredos, n8n local | ✅ Concluída |
| 1. Coleta | Agendador, configuração do tema, Google News RSS por termo, remoção de duplicadas, filtro de 24h | ✅ Concluída |
| 2. Agente de Triagem | IA classifica cada notícia (relevância, tom, aderência ao cliente, mensagens-chave) com saída em JSON validado | ✅ Concluída |
| 3. Redator e Revisor | IA monta o relatório e outra IA confere se nada foi inventado | ⏳ |
| 4. Entrega e registro | Telegram, Gmail e Google Sheets; busca tudo desde a última execução, sem repetir notícias já enviadas | ⏳ |
| 5. Erros e métricas | Tratamento de falhas e log de cada execução | ⏳ |
| 6. Portfólio | Diagrama, prints, métricas reais e documentação final | ⏳ |

## Como funciona (até agora)

```
Agendador (10h e 19h) ─┐
                       ├→ Configuração → Montar buscas → Coleta RSS → Limpeza
Executar agora ────────┘
   → Montar lotes → Triagem (Gemini) → Validar triagem → Só relevantes
```

- **Disparo:** o fluxo roda às 10h e às 19h, ou na hora em que eu clicar em **Executar agora**. O n8n roda no meu computador, então o botão cobre os horários em que ele estiver desligado.
- **Configuração:** um único nó onde quem usa define o `tema`, o `foco_do_cliente`, os `termos_de_busca` e as `mensagens_chave`. O repositório traz um exemplo fictício de **Automóveis**.
- **Coleta:** uma busca no Google News RSS para cada termo.
- **Limpeza (sem IA):** junta os resultados, remove repetidas e mantém só as últimas 24h. A mesma matéria em veículos diferentes conta como duas inserções, como no clipping de assessoria.
- **Triagem (IA):** as notícias vão em lotes de 10 para o Gemini 3.5 Flash Lite, que devolve, para cada uma:
  - **relevância:** se o tema é o assunto principal (ocorrências policiais, sorteios e anúncios ficam de fora)
  - **tom:** positivo, neutro ou negativo para o negócio do cliente
  - **aderência:** alta, média ou baixa em relação aos interesses do cliente
  - **mensagens-chave** encontradas, um resumo curto e o motivo da decisão
- **Validação (sem IA):** a resposta precisa seguir um JSON Schema. Um nó de código confere se todas as notícias voltaram classificadas, corrige valores fora do padrão e descarta mensagens-chave que a IA tenha inventado.

Execução de teste da Fase 2: **97 notícias classificadas em 10 chamadas à IA, 68 relevantes, nenhuma perdida por erro.**

O prompt, o schema, as decisões e os ajustes feitos em cada teste estão em [`prompts/01-triagem.md`](prompts/01-triagem.md).

### Limitações conhecidas

- O RSS do Google News não traz trecho das matérias, só título e veículo. Por isso a triagem decide pelo título.
- A mesma notícia, publicada por veículos diferentes, às vezes recebe classificações diferentes, porque cada lote é uma chamada independente à IA.

## Tecnologias

- [n8n](https://n8n.io) (automação, rodando localmente)
- Google News RSS
- Gemini API (plano gratuito): Gemini 3.5 Flash Lite na triagem

## Uso de IA

Projeto desenvolvido por mim com o [Claude Code](https://claude.com/claude-code) como parceiro de programação. Os commits feitos em conjunto levam a linha `Co-Authored-By: Claude`. Os detalhes de como essa parceria funcionou entram na versão final deste README.

## Direitos autorais

O clipping guarda só título, veículo, data, link e um resumo curto que a IA escreve a partir do título. O texto completo das matérias nunca é copiado.

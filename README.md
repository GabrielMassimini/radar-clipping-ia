# Radar de Notícias com IA

Clipping automático de notícias com **n8n** e **agentes de IA**. Todo dia às 7h, o fluxo busca notícias sobre um tema, filtra, classifica e resume, e entrega um relatório no Telegram e no e-mail.

> 🚧 **Projeto em construção.** O README é atualizado ao fim de cada fase.

## O problema

Na assessoria de imprensa, o clipping (procurar, ler e organizar as notícias sobre um cliente e conferir se elas trazem as mensagens-chave dele) é feito à mão e leva de 30 minutos a 1 hora por dia. Além do tempo, sempre existe o risco de deixar alguma notícia passar. Este projeto automatiza esse trabalho.

## Status

| Fase | O que entrega | Status |
|---|---|---|
| 0. Ambiente | Estrutura do repositório, proteção de segredos, n8n local | ✅ Concluída |
| 1. Coleta | Agendador, configuração do tema, Google News RSS por termo, remoção de duplicadas, filtro de 24h | ✅ Concluída |
| 2. Agente de Triagem | IA classifica cada notícia (relevância, sentimento, mensagens-chave) com saída em JSON validado | 🚧 Próxima |
| 3. Redator e Revisor | IA monta o relatório do dia e outra IA confere se nada foi inventado | ⏳ |
| 4. Entrega e registro | Telegram, Gmail e Google Sheets | ⏳ |
| 5. Erros e métricas | Tratamento de falhas e log de cada execução | ⏳ |
| 6. Portfólio | Diagrama, prints, métricas reais e documentação final | ⏳ |

## Como funciona (até agora)

```
Agendador (7h) → Configuração → Montar buscas → Coleta RSS → Limpeza
```

- **Configuração:** um único nó onde quem usa define o `tema`, os `termos_de_busca` e as `mensagens_chave`. O repositório traz o exemplo **Automóveis**.
- **Coleta:** uma busca no Google News RSS para cada termo.
- **Limpeza (sem IA):** junta os resultados, remove repetidas e mantém só as últimas 24h. A mesma matéria em veículos diferentes conta como duas inserções, como no clipping de assessoria.

Primeiro teste real com o tema de exemplo: **184 notícias coletadas, 10 duplicadas removidas, 174 seguem para a triagem.**

## Tecnologias

- [n8n](https://n8n.io) (automação, rodando localmente)
- Google News RSS
- Gemini API (plano gratuito), a partir da Fase 2

## Uso de IA

Projeto desenvolvido por mim com o [Claude Code](https://claude.com/claude-code) como parceiro de programação. Os commits feitos em conjunto levam a linha `Co-Authored-By: Claude`. Os detalhes de como essa parceria funcionou entram na versão final deste README.

## Direitos autorais

O clipping guarda só título, veículo, data, link e um resumo curto gerado a partir do trecho do RSS. O texto completo das matérias nunca é copiado.

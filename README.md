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
| 3. Redator e Revisor | IA agrupa a mesma notícia e escreve os resumos, outra IA confere se nada foi inventado, e o relatório final é montado | ✅ Concluída |
| 4. Entrega e registro | Telegram, Gmail e Google Sheets; busca tudo desde a última execução, sem repetir notícias já enviadas | ✅ Concluída |
| 5. Erros e métricas | Tratamento de falhas e log de cada execução | ⏳ |
| 6. Portfólio | Diagrama, prints, métricas reais e documentação final | ⏳ |

## Como funciona (até agora)

```
Agendador (10h e 19h) ─┐
                       ├→ Configuração → Ler log → Ler notícias → Calcular janela
Executar agora ────────┘
   → Montar buscas → Coleta RSS → Limpeza
   → Montar lotes → Triagem (Gemini) → Validar triagem
   → Preparar redação → Redator (Gemini) → Validar redação
   → Preparar revisão → Revisor (Gemini) → Aplicar revisão → Montar relatório
   ├→ Dividir para Telegram → Telegram
   └→ Gmail ┬→ Preparar notícias → Registrar notícias (Sheets)
            └→ Preparar log → Registrar log (Sheets)
```

- **Disparo:** o fluxo roda às 10h e às 19h, ou na hora em que eu clicar em **Executar agora**. O n8n roda no meu computador, então o botão cobre os horários em que ele estiver desligado.
- **Configuração:** um único nó onde quem usa define o `tema`, o `foco_do_cliente`, os `termos_de_busca`, as `mensagens_chave` e os destinos do relatório. O repositório traz um exemplo fictício de **Automóveis**.
- **Janela de busca (sem IA):** o fluxo lê na planilha quando rodou pela última vez e busca desde esse momento, com 1 hora de folga. Se o computador ficar desligado por dias, nada se perde: a busca volta até 7 dias. Na primeira execução, sem histórico, usa 24 horas.
- **Coleta:** uma busca no Google News RSS para cada termo.
- **Limpeza (sem IA):** junta os resultados, remove repetidas, mantém só o que está dentro da janela e tira o que já foi enviado. A mesma matéria em veículos diferentes conta como duas inserções, como no clipping de assessoria.
- **Triagem (IA):** as notícias vão em lotes de 10 para o Gemini 3.5 Flash Lite, que devolve, para cada uma:
  - **relevância:** se o tema é o assunto principal (ocorrências policiais, sorteios e anúncios ficam de fora)
  - **tom:** positivo, neutro ou negativo para o negócio do cliente
  - **aderência:** alta, média ou baixa em relação aos interesses do cliente
  - **mensagens-chave** encontradas, um resumo curto e o motivo da decisão
- **Validação (sem IA):** a resposta precisa seguir um JSON Schema. Um nó de código confere se todas as notícias voltaram classificadas, corrige valores fora do padrão e descarta mensagens-chave que a IA tenha inventado.
- **Redator (IA):** agrupa as notícias que tratam do mesmo fato, mesmo com títulos diferentes, e escreve um panorama do período e um resumo de cada grupo, usando só o que está nos títulos.
- **Regras do grupo (sem IA):** um grupo entra no relatório se pelo menos uma cópia foi relevante, para nenhuma inserção do assunto ficar de fora. Tom e aderência saem da maioria das cópias relevantes. Título, veículos, links e contagens vêm dos dados, então a IA não tem como inventá-los.
- **Revisor (IA):** confere cada texto contra os títulos e aponta o que não está neles. Ele não reescreve nada.
- **Aplicar revisão (sem IA):** o código retira o que foi apontado. O resumo reprovado é apagado, e a notícia fica só com título e veículos. No panorama, sai só a frase com problema. Se o Revisor falhar, o relatório sai sem textos da IA.
- **Relatório (sem IA):** panorama, números, destaques, setor, outras notícias e mensagens-chave. Em cada seção, as notícias negativas vêm primeiro.
- **Entrega:** o relatório vai para o Telegram, dividido em mensagens que respeitam o limite de caracteres e de formatações, e para o Gmail, em uma mensagem só. A edição é **manhã** antes das 14h e **noite** a partir daí.
- **Registro (Google Sheets):** cada notícia enviada vira uma linha na aba `noticias`, e cada execução, uma linha na aba `log`, com os números daquela rodada. Essa planilha é também a memória do fluxo: é dela que ele tira a janela de busca e a lista do que já foi enviado.

Execução de teste da Fase 3, com notícias de um dia novo: **95 notícias classificadas, 48 relevantes, sobre 44 fatos, nenhuma perdida por erro, em cerca de 3 minutos e meio.**

Teste da Fase 4, rodando 1h24 depois de um envio completo: das **117 notícias coletadas, 43 foram reconhecidas como já enviadas e 5 eram novas**, com 2 relevantes. Nenhuma repetiu, e a execução levou 33 segundos.

Os prompts, os schemas, as decisões e os ajustes feitos em cada teste estão na pasta [`prompts/`](prompts/): [Triagem](prompts/01-triagem.md), [Redator](prompts/02-redator.md) e [Revisor](prompts/03-revisor.md).

### Decisão: trocar o modelo antes do previsto

O plano era testar o Redator e o Revisor no Flash Lite, por causa do limite gratuito, e só trocar de modelo no fim. Os testes anteciparam a troca, porque o Flash Lite classifica bem, mas segue mal regras finas de escrita. Mesmo com a regra proibindo com exemplos literais, ele continuava usando adjetivos que não estavam nos títulos. Melhorar o prompt não resolveu, porque o limite era do modelo.

Testei então os modelos Flash, com o mesmo prompt:

| Modelo do Redator | Resumos reprovados pelo Revisor | Tempo do Redator |
|---|---|---|
| Gemini 3.6 Flash | 11 de 40 | cerca de 1 minuto |
| Gemini 3.8 Flash | 3 de 35 | 18 minutos e 42 segundos |

O 3.8 escreveu melhor, mas levou o fluxo a 24 minutos. Fiquei com o 3.6 Flash: como o resumo reprovado sai do relatório, a diferença de qualidade não compensa esse tempo. Com a troca, a execução caiu para algo entre 2 e 3 minutos e meio, conforme o volume de notícias. O fluxo também ganhou um tempo máximo de 15 minutos, porque uma chamada externa pode demorar indefinidamente.

### Decisão: como reconhecer uma notícia já enviada

O plano era usar o link. Antes de construir, comparei duas execuções seguidas: de 80 notícias iguais em título e veículo, só 76 tinham o mesmo link, porque o Google News às vezes gera outro endereço para a mesma matéria. Com esse plano, 1 notícia em cada 20 voltaria repetida. Por isso, a notícia é reconhecida pelo link **ou** pela combinação de título e veículo.

### Limitações conhecidas

- O RSS do Google News não traz trecho das matérias, só título e veículo. Por isso, os agentes trabalham pelo título: conseguem dizer do que a notícia trata, mas não medir o peso dela. Uma nota curta pode aparecer como destaque.
- O Revisor reduz os erros, mas não elimina todos. No último teste, ele passou a apontar uma causa inventada no panorama, mas deixou passar uma palavra que forçava o sentido do título ("aceleração nas vendas" no lugar de "vendem mais rápido").
- Parte dos exemplos dos prompts saiu dos próprios testes. Por isso, o teste decisivo é sempre com notícias que o fluxo nunca viu.
- Cada busca do RSS traz no máximo 100 notícias. Em uma janela longa, como depois de vários dias com o computador desligado, as mais antigas podem ficar de fora.
- Só as notícias relevantes vão para a planilha. As descartadas podem ser classificadas de novo se ainda estiverem dentro da janela.
- Por enquanto, uma falha no envio interrompe o fluxo, e uma execução sem notícias novas termina sem aviso. Esses dois casos são tratados na Fase 5.
- Na minha rede, o IPv6 falha de vez em quando na conexão com o Telegram. Por isso, o n8n é iniciado com `NODE_OPTIONS=--dns-result-order=ipv4first`, e os envios tentam de novo em caso de erro.

## Tecnologias

- [n8n](https://n8n.io) (automação, rodando localmente)
- Google News RSS
- Gemini API (plano gratuito): Gemini 3.5 Flash Lite na triagem, Gemini 3.6 Flash no Redator e no Revisor
- Telegram Bot API e Gmail (entrega)
- Google Sheets (histórico e log)

O acesso à conta Google está descrito na [política de privacidade](docs/privacidade.md).

## Uso de IA

Projeto desenvolvido por mim com o [Claude Code](https://claude.com/claude-code) como parceiro de programação. Os commits feitos em conjunto levam a linha `Co-Authored-By: Claude`. Os detalhes de como essa parceria funcionou entram na versão final deste README.

## Direitos autorais

O clipping guarda só título, veículo, data, link e um resumo curto que a IA escreve a partir do título. O texto completo das matérias nunca é copiado.

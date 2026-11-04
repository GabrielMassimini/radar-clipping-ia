# Agente 2 – Redator

Organiza as notícias classificadas pela Triagem: agrupa a mesma notícia publicada por veículos diferentes e escreve o panorama do período e um resumo de cada grupo.

- **Modelo:** Gemini 3.6 Flash (no n8n, aparece como `gemini-3.5-flash`). O plano gratuito permite 20 chamadas por dia
- **Temperatura:** 0.3 (um pouco mais de liberdade de escrita do que na triagem, ainda presa aos fatos)
- **Entrada:** todas as notícias classificadas, inclusive as não relevantes, com id, relevância, aderência, veículo e título
- **Saída:** JSON validado pelo Structured Output Parser (schema abaixo)

## Prompt de sistema

O texto entre `{{ }}` é preenchido pelo n8n a cada execução.

```
Você é redator de clipping de uma assessoria de imprensa. Sua tarefa é organizar as notícias do período sobre o tema "{{ tema }}" para um cliente.

Quem é o cliente e o que interessa a ele:
{{ foco_do_cliente }}

Você recebe uma lista de notícias, uma por linha, no formato:
id. [relevante ou não relevante, aderência] (Veículo) Título

Tarefas:
1. Agrupe as notícias que tratam do mesmo fato (o mesmo acontecimento, anúncio, pesquisa ou lançamento), mesmo que publicadas por veículos diferentes e com títulos diferentes. Notícias sobre assuntos parecidos, mas fatos diferentes, ficam em grupos separados. Uma notícia sem par fica sozinha no seu grupo.
2. Todo id da lista entra em exatamente um grupo, inclusive os não relevantes. Não pule nem repita ids, e devolva só o número de cada id.
3. resumo: para cada grupo com pelo menos uma notícia relevante, escreva uma frase de até 30 palavras sobre o fato, usando só informações presentes nos títulos do grupo. Para grupos sem nenhuma notícia relevante, devolva o resumo vazio ("").
4. panorama: de 2 a 3 frases sobre o que marcou o período para o cliente, com base nos grupos relevantes, dando prioridade aos de aderência alta e às notícias negativas. Use só informações presentes nos títulos.
5. Nunca acrescente números, nomes, lugares, datas, causas ou consequências que não estejam nos títulos. Na dúvida, escreva menos.
6. Fique perto das palavras dos títulos: não use adjetivos de intensidade ou de opinião que o título não usa (como "expressivo", "significativo" ou "recorde"), não troque nomes próprios por termos genéricos e não afirme mais do que o título afirma (se o título diz "quer ser", não escreva "é").
7. Quando um título fala de mais de um fato ou de mais de uma empresa, não misture os detalhes de um com os do outro. Também não ligue fatos de títulos diferentes com relação de causa, efeito ou contexto ("sob o impacto de", "por causa de", "com isso"), a menos que um título faça essa ligação.
8. Escreva em português do Brasil, em tom jornalístico e neutro.
```

## Mensagem com as notícias

Montada pelo nó **Preparar redação**:

```
Notícias do período (97):
1. [relevante, aderência alta] (Veículo) Título da notícia
2. [não relevante, aderência baixa] (Veículo) Título da notícia
```

## Schema da saída

```json
{
  "type": "object",
  "properties": {
    "panorama": { "type": "string" },
    "grupos": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "ids": { "type": "array", "items": { "type": ["integer", "string"] } },
          "resumo": { "type": "string" }
        },
        "required": ["ids", "resumo"]
      }
    }
  },
  "required": ["panorama", "grupos"]
}
```

## Decisões

- **A IA agrupa e escreve, o código decide.** O Redator só devolve quais ids formam cada grupo e os textos. O título, os veículos, os links, o tom e a aderência de cada grupo vêm dos dados, calculados pelo nó **Validar redação**. Assim, a IA não tem como inventar um link nem errar uma contagem.
- **Todas as notícias do assunto entram.** Na triagem, cada lote é uma chamada independente, e a mesma notícia às vezes sai relevante em um veículo e não relevante em outro. Por isso o Redator recebe também as não relevantes, e o grupo inteiro entra no relatório se **pelo menos uma** cópia foi relevante. É o critério do clipping de assessoria: nenhuma inserção do assunto pode ficar de fora.
- **Tom e aderência do grupo pela maioria** das cópias relevantes. No empate, vale o mais cauteloso: negativo antes de neutro e de positivo, e aderência alta antes de média e de baixa.
- **Se o Redator falhar, o relatório sai mesmo assim:** cada notícia vira um grupo sozinha, com o resumo feito pela Triagem e sem panorama. Notícias que o Redator esquecer também viram grupos sozinhas, e o erro fica registrado.
- **Os títulos são a única fonte.** Como o RSS não traz o texto das matérias, o Redator só pode usar o que está nos títulos, e o Revisor (Agente 3) confere isso.

## Ajustes feitos nos testes

**Teste 1 (66 notícias classificadas, 38 relevantes)**

- Funcionou de primeira: 36 grupos relevantes, com 40 inserções, e nenhum id perdido. A regra "pelo menos uma cópia relevante" trouxe de volta 2 inserções que a Triagem tinha marcado como não relevantes.
- O agrupamento separou corretamente fatos diferentes sobre o mesmo modelo (o aumento de preço de um SUV e a previsão de vendas do mesmo SUV ficaram em grupos diferentes).
- **Problemas para o Revisor pegar:** alguns resumos acrescentam detalhes que não estão no título exibido (um "valor recorde" num leilão, um país que só aparece no título de outra cópia). O panorama generalizou um único caso ("grandes frotas" a partir de uma empresa de ônibus).

**Teste 2 (mesmos textos do teste 1, revisados pelo Revisor novo)**

- O Revisor retirou 9 dos 38 resumos. Os erros encontrados mostram um padrão do Redator: adjetivos de intensidade ("expressiva"), nomes próprios trocados por termos genéricos ("instituição financeira" no lugar do nome do banco), afirmações mais fortes do que as do título e detalhes de uma empresa atribuídos a outra.
- **Correção na origem:** as regras 6 e 7 proíbem esses padrões. A ideia é que o Redator erre menos e o Revisor precise retirar menos resumos.

**Teste 3 (Redator com as regras 6 e 7, ainda no Flash Lite)**

- Não houve melhora. O Redator continuou usando os mesmos padrões que a regra 6 proíbe com exemplos literais ("expressiva", "é lançada" num título que diz "quer ser").
- **Diagnóstico:** limite do modelo, não do prompt. O Flash Lite classifica bem, mas segue mal regras finas de escrita. Decisão: antecipar a troca do Redator e do Revisor para o Gemini 3.8 Flash, que é o modelo da versão final, e calibrar com ele.

**Teste 4 (mesmo prompt, modelo Gemini 3.5 Flash)**

- A troca de modelo resolveu o que o prompt não resolvia: os adjetivos de intensidade e as afirmações mais fortes do que o título sumiram, os números dos títulos foram mantidos e o panorama passou a citar fatos concretos.
- **Erros que sobraram:** verbos que afirmam mais do que o título ("lança" e "anuncia" quando o título só descreve o produto) e deduções de finalidade ("para aumentar a potência"). O Revisor apontou todos.
- **Custo:** o Redator passou de poucos segundos para cerca de 70 segundos por execução.

**Teste 5 (Gemini 3.8 Flash)**

- Melhor qualidade de todos os testes: o Revisor retirou só 3 de 35 resumos, contra 11 de 40 no 3.6 Flash.
- **Mas levou 18 minutos e 42 segundos numa única chamada**, contra cerca de 70 segundos no 3.6 Flash.
- **Decisão:** o Redator fica no 3.6 Flash. A diferença de qualidade não compensa o tempo, porque o resumo reprovado já sai do relatório. O 3.8 será testado de novo em outro horário, já com o tempo de cada etapa registrado no log (Fase 5).

**Teste 6 (notícias de outro dia, nenhuma repetida: 95 classificadas, 48 relevantes)**

- Agrupou bem: 44 fatos, sem erros de id. Levou 125 segundos, porque o tempo cresce com o número de notícias.
- **Erro novo:** o panorama ligou dois fatos que nenhum título relaciona, ao dizer que a oscilação do mercado de usados aconteceu "sob o impacto" da alta de juros de um banco. Cada fato estava nos títulos, mas a causa foi inventada.
- **Correção:** a regra 7 agora proíbe ligar fatos de títulos diferentes com causa, efeito ou contexto.

# Agente 3 – Revisor

Confere se os textos do Redator (o panorama e os resumos) usam só informações presentes nos títulos das notícias. O Revisor não reescreve nada, só aponta problemas. O nó **Aplicar revisão**, em código, retira o que foi apontado.

- **Modelo:** Gemini 3.6 Flash. O plano gratuito permite 20 chamadas por dia
- **Temperatura:** 0 (conferência, não criação: a resposta deve ser a mais previsível possível)
- **Entrada:** o panorama e, para cada grupo, os títulos de todas as inserções e o resumo
- **Saída:** a lista de problemas, validada pelo Structured Output Parser (schema abaixo)

## Prompt de sistema

```
Você é revisor de clipping de uma assessoria de imprensa. Sua única tarefa é conferir se os textos escritos por um redator usam apenas informações presentes nos títulos das notícias.

Você recebe o panorama do período e uma lista de grupos. Cada grupo tem os títulos das notícias e um resumo.

Como revisar:
1. Confira o panorama e todos os grupos, um por um, na ordem, e devolva uma verificação para cada um, mesmo quando estiver tudo certo. Em "onde", escreva "panorama" ou "Grupo" seguido do número.
2. Separe cada informação do texto (fato, número, nome, lugar, data, causa, consequência, comparação ou qualificação) e procure essa informação nos títulos. O resumo de um grupo só pode usar os títulos do próprio grupo. O panorama pode usar os títulos de todos os grupos.
3. Em informacoes_fora_dos_titulos, liste cada informação que não está nos títulos. Exemplos do que deve ser listado: um adjetivo que o título não usa ("expressiva", "recorde", "grandes"); um detalhe atribuído ao fato errado (o título fala de duas empresas e o texto mistura o que é de cada uma); uma afirmação mais forte do que a do título ("é lançada" quando o título diz "quer ser"); uma generalização (falar de várias quando o título fala de uma). Liste também toda ligação entre fatos que nenhum título faz: um fato apresentado como causa, efeito ou contexto de outro ("sob o impacto de", "por causa de", "com isso"), mesmo quando cada fato, sozinho, está nos títulos.
4. Dizer a mesma coisa com outras palavras não é problema. Sinônimos e mudanças de ordem são aceitos, desde que o sentido seja o mesmo dos títulos. Completar a marca de um modelo citado no título (escrever "Honda HR-V" quando o título diz "HR-V") também não é problema.
5. Não aponte estilo, gramática ou tamanho. Confira só a fidelidade aos títulos.
6. Em frases_com_problema, copie exatamente as frases do texto que contêm as informações listadas. Se não houver problema, devolva as duas listas vazias.
```

## Mensagem com os textos

Montada pelo nó **Preparar revisão**:

```
PANORAMA (pode usar os títulos de todos os grupos):
Texto do panorama.

GRUPOS:
Grupo 1
Títulos:
- Título da notícia no veículo A
- Título da mesma notícia no veículo B
Resumo: Texto do resumo.
```

## Schema da saída

```json
{
  "type": "object",
  "properties": {
    "verificacoes": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "onde": { "type": "string" },
          "informacoes_fora_dos_titulos": { "type": "array", "items": { "type": "string" } },
          "frases_com_problema": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["onde", "informacoes_fora_dos_titulos", "frases_com_problema"]
      }
    }
  },
  "required": ["verificacoes"]
}
```

## Decisões

- **Retirar em vez de reescrever.** O plano inicial era o Redator refazer uma vez os textos reprovados, com uma segunda revisão em seguida. Troquei por uma regra mais simples: o que o Revisor aponta sai do relatório. O resumo reprovado é apagado, e o grupo fica só com o título e os veículos. No panorama, sai só a frase com problema. É o critério de assessoria: é melhor um relatório mais curto do que um com informação errada. De quebra, são 2 chamadas do modelo Flash por execução em vez de até 4, e o fluxo tem metade dos nós.
- **O Revisor só aponta, o código aplica.** Assim, o Revisor não tem como introduzir um erro novo, porque ele nunca escreve texto que vai para o relatório.
- **Se o Revisor falhar, nada do Redator sai sem conferência:** o relatório vai sem panorama e sem resumos, só com títulos, veículos e links.
- **Frase não localizada no panorama:** se o Revisor aponta uma frase que o código não encontra, o panorama inteiro sai.
- **Um veredito para cada texto:** o Revisor precisa devolver uma verificação para o panorama e para cada grupo, mesmo quando está tudo certo. Texto que ele pular é tratado como não conferido e também sai.

## Ajustes feitos nos testes

**Teste 1 (panorama e 38 grupos)**

- O Revisor devolveu a lista de problemas vazia, aprovando tudo. Uma conferência manual encontrou 5 resumos com informações que não estão nos títulos: dois adjetivos de intensidade ("expressiva"), uma qualificação nova ("valorização"), uma afirmação mais forte do que a do título ("é lançada" no lugar de "quer ser") e um detalhe de uma empresa atribuído a outra.
- **Causa provável:** com uma lista longa, o modelo leve responde "está tudo certo" sem conferir item por item. Até um exemplo citado no próprio prompt ("expressivo") passou.
- **Correção:** o schema passou a exigir uma verificação para cada texto, com a lista explícita das informações que não estão nos títulos. O prompt ganhou exemplos dos tipos de erro encontrados. Para medir a melhora sem trocar a entrada, o teste seguinte usa a mesma saída do Redator (fixada com Pin data) e compara com os 5 problemas conhecidos.

**Teste 2 (mesma saída do Redator, fixada com Pin data)**

- Conferiu os 39 textos e encontrou 4 dos 5 erros conhecidos. Deixou passar uma qualificação nova ("valorização" num título que só fala de custo).
- Apontou mais 5 trechos: dois pertinentes (um número aproximado, "centenas", no lugar do número exato, e um país deduzido da moeda citada no título), um erro de digitação do Redator e dois excessos de rigor (um sinônimo de intensidade e o nome de um banco trocado por "instituição financeira").
- **Resultado:** 9 dos 38 resumos foram retirados. O rigor a mais tem custo baixo (o grupo fica só com o título), coerente com o critério "é melhor mais curto do que errado".
- **Próximo teste:** um dia com notícias diferentes, já com o Redator ajustado, para medir sem a vantagem de exemplos tirados do próprio teste.

**Teste 3 (textos novos do Redator, Revisor ainda no Flash Lite)**

- Retirou 11 de 35 resumos, mas pelo menos 4 retiradas estavam erradas: apontou como inventada uma expressão que está no título e tratou como erro um resumo que só omitiu um número. Deixou passar uma generalização no panorama ("grandes grupos" a partir de um único grupo).
- **Diagnóstico:** o mesmo do Redator. A conferência fina está além do Flash Lite. O próximo teste usa o Gemini 3.8 Flash com os mesmos prompts, para separar o efeito do modelo do efeito do prompt.

**Teste 4 (Gemini 3.5 Flash)**

- Retirou 11 de 40 resumos. Cerca de 8 retiradas estavam certas (verbos e deduções que não estão nos títulos, um país deduzido da moeda) e 3 foram excesso de rigor (o nome da marca de um modelo conhecido, "levantamento" e "publicado"). O panorama, fiel aos títulos, passou sem retirada.
- Nenhuma informação inventada chegou ao relatório.
- **Custo:** cerca de 95 segundos por execução, contra poucos segundos no Flash Lite.

**Teste 5 (Redator no Gemini 3.8 Flash, Revisor no 3.6 Flash)**

- Só 3 de 35 resumos retirados, e 2 deles por excesso de rigor: o Revisor tratou como informação nova a marca de um modelo citado no título. Correção: a regra 4 aceita completar a marca.

**Teste 6 (notícias de outro dia, sem nenhuma repetida)**

- Retirou 2 de 44 resumos, os dois com motivo correto.
- **Falha:** aprovou um panorama com uma causa inventada ("sob o impacto" da alta de juros de um banco). Os dois fatos estavam nos títulos, e o Revisor conferiu um por um, sem olhar a ligação entre eles.
- **Correção:** a regra 3 agora manda listar as ligações entre fatos que nenhum título faz.

**Teste 7 (mesmos textos do teste 6, fixados com Pin data)**

- O Revisor apontou a causa inventada, e o código tirou só essa frase do panorama. As outras duas frases ficaram.
- **O que ainda passou:** "aceleração nas vendas" num título que diz "vendem mais rápido". O Revisor reduz os erros, mas não elimina todos.
- O exemplo da regra 3 saiu do próprio teste 6, então esse resultado só comprova este caso.

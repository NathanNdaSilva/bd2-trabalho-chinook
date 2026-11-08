
**Regra 1: Somente funcionários com cargo de ‘Sales Support Agent’ podem ser atribuídos como representantes de suporte.**
Para definirmos as regras semânticas primeiramente devemos abordar como a tabela chinook está estruturada. A tabela customer possui uma coluna chamada SupportRepId, que está relacionada com a tabela employee. Nessa tabela empoyee existe uma coluna de nome Title, que contém os tipos de funcionários, como ‘Sales Support Agent’, ‘IT Staff’, etc. As restrições estruturais podem garantir que exista sempre um SupportRepId associado a um cliente, porém não consegue verificar se esse employee pode ou não agir como representante de suporte. Para agir como representante de suporte, o funcionário deve ter o Title de 'Sales Support Agent'.

**Regra 2: O preço unitário registrado em um item de fatura não pode ser inferior ao preço unitário de catálogo**
Outro caso que originou na segunda regra provém da tabela track, onde há o atributo UnitPrice que guarda o preço da música em questão. O registro de vendas ocorre na tabela invoiceline, que também grava UnitPrice na venda. A chave estrangeira de TrackId em invoiceline garante que a música exista, porém não há nenhuma restrição em relação a inserção de um item na fatura cobrando um valor menor que o preço de tabela da música. Ou seja, o valor de UnitPrice na tabela invoiceline não deve ser menor que o valor de UnitPrice da tabela Track. 




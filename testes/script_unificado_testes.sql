# 🗄️ Projeto de Banco de Dados II - Sistema Chinook

Repositório oficial do trabalho em grupo da disciplina de **Banco de Dados II** da Universidade Federal Fluminense (UFF), ministrada pelo Prof. Rodrigo Salvador Monteiro. O projeto implementa scripts de catálogo, procedimentos, validações de DTE, regras semânticas, triggers e procedimentos com controle de acesso sobre o SGBD **MySQL** utilizando o banco de exemplo **Chinook**.

---

## 🚀 Decisões Arquiteturais e Tecnologias

Para garantir a padronização do desenvolvimento e a reprodutibilidade dos scripts pela equipe, as seguintes diretrizes tecnológicas foram adotadas:

* **SGBD:** MySQL (conforme acordado previamente com a disciplina).
* **Linguagem Procedural:** SQL procedural nativo do MySQL (`BEGIN ... END`, loops, cursores e blocos de controle de fluxo para Stored Procedures e Triggers).
* **Ferramenta de Gerenciamento e Testes:** [MySQL Workbench](https://www.dev.mysql.com/downloads/workbench/) como ambiente padrão de modelagem, execução de scripts e depuração.
* **Modelo de Dados:** Chinook Database (versão oficial para MySQL baseada no repositório de referência).

---

## 📂 Estrutura do Repositório

O projeto está estruturado modularmente para separar a camada de base, os scripts de lógica procedimental (Partes 1 e 2) e a suíte de testes integrados:

```text
bd2-trabalho-chinook/
├── README.md                      <-- Documentação principal e arquitetura do projeto
├── schema/
│   └── Chinook_MySql.sql          <-- Script oficial de criação e carga inicial da base Chinook
├── parte1/
│   ├── 01_indices_catalogo.sql    <-- Tarefa 1: Listagem de índices via catálogo
│   ├── 02_procedure_drop.sql      <-- Tarefa 2: Procedure para remoção dinâmica de índices
│   ├── 03_fks_catalogo.sql        <-- Tarefa 3: Listagem de chaves estrangeiras via catálogo
│   ├── 04_gerador_ddl.sql         <-- Tarefa 4: Gerador dinâmico de DDL (Create Table) a partir do catálogo
│   └── 05_validador_dte.sql       <-- Tarefa 5: Validador de Diagrama de Transição de Estados (DTE)
├── parte2/
│   ├── 01_regras_semanticas.md    <-- Tarefa 6: Descrição textual das regras semânticas
│   ├── 02_trigger_semantica.sql   <-- Tarefa 7: Triggers para validação das regras semânticas
│   ├── 03_procedure_grant.sql     <-- Tarefa 8: Procedures com restrição de privilégios e usuários
│   └── 04_trigger_total.sql       <-- Tarefa 9: Integridade relacional da coluna Total (Invoice vs InvoiceLine)
└── testes/
    └── script_unificado_testes.sql <-- Tarefa 10: Cenários de testes integrados e validações

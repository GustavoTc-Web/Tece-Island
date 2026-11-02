# Auditoria da exportação de saves — 02/11/2026

**Conclusão: tratar como backup privado do navegador. Não é relatório anônimo
para suporte nem arquivo adequado para issue pública.** A exportação inclui
dados de outras contas que tenham saves nessa mesma origem e perfil.

## Versão e método

Oficial **0.9.1-beta.1**, commit publicado `fbc56f75c60ae690f5a101516145a384c9fa1304`.
Manifesto, HTML servido, hash do shell de origem e PCK público conferidos.
PCK SHA-256: `db7c52b3a9a185ecda220817c6134a01473e2c46ce812f938c119b418e03c358`.

Foram criados dois mundos de teste pelo cliente publicado em contexto descartável
do Edge headless. As duas identidades e suas credenciais eram inteiramente
sintéticas, com respostas Auth interceptadas só no navegador. Nenhuma criação
de conta, autenticação ou escrita foi enviada ao Firebase de produção.
Nenhum perfil, senha, token ou save real do usuário foi lido. Não é teste físico.

A função real `tcExportLocalSaves()` foi chamada, equivalente ao handler do
botão no lobby, e seu download `tece-island-saves.json` foi examinado. Casos
adicionais de backup/migração/legado/entrada inválida foram preparados apenas
no banco descartável. A função não modificou o banco durante a exportação.
**17 verificações aprovadas**; [resultado sem valores](validation/save-export-audit/results.json).

## Campos e alcance

| Conteúdo | Campos / significado | Privacidade |
| --- | --- | --- |
| Envelope | `format`, `origin`, `exportedAt`, `entries` | Origem do site e data/hora da exportação |
| Entrada | `key`, `value` sem filtragem | Chaves por hash da conta/ID do mundo; valores e versões anteriores intactos |
| Catálogo | `version`, `owner_uid`, `worlds`, `servers`, `migration_done` | UID em texto, IDs e nomes de mundos, último acesso; histórico de servidores com nome/endereço/porta se existir |
| Save | `version`, `owner_uid`, `world_id`, `world_name`, `world_seed` | Identificação da conta e do mundo; nome livre pode conter nome pessoal ou e-mail |
| Personagem e inventário | `player`, `inventory`, `elapsed`, `bed` quando definida | Posição no jogo, vida, fome, água, veneno, itens, quantidades, atributos, identidades de armas e seleção |
| Mundo e campanha | `structures`, `drops`, `resources`, `loot`, `wells`, `explored`, `generated_regions`, `region_wells`, `region_buildings`, `building_loot`, `building_interiors`, `wells_policy`, `journal`, `objectives`, `campaign` | Progresso completo, construções/baús e seus nomes livres, exploração, loot, guardiões, tarefas e sono |
| Sincronização | `_sync` quando presente: revisão, hash, horário de atualização e eventual `intent` com hash/revisão | Metadados de consistência; não são sessão nem tokens de autenticação |
| Preservados | `:backup`, `:backup-2`, `:before-v9`, outras migrações, conflitos, cópias antes da nuvem, registros de legado/importação e entradas ilegíveis se existirem | Também exportados, mesmo sem schema reconhecido ou vínculo com a conta conectada |

O banco lido é **`tece-island-progress-v4`**, object store **`saves`**, nessa
origem/perfil do navegador. Não são incluídos automaticamente os outros perfis,
outros navegadores/aparelhos/origens, dados remotos não baixados, cookies,
localStorage, sessionStorage, formulário de login, memória Auth ou histórico
de chat. O script separado `tools/export-browser-saves.js` tem alcance maior
(inclui bancos Godot/userfs antigos); não é o botão auditado.

## Credenciais, codificação e conteúdo pessoal

- No fluxo normal criado pelo aplicativo, **não foram exportados** senha,
  Firebase ID/access token, refresh token, e-mail do login ou marcador de sessão.
  Os sentinelas sintéticos foram comparados sem publicar seus valores.
  O código mantém esses dados Auth em memória e não os escreve nesse banco.
- O arquivo normal era JSON em texto; `entries[].value` contém em geral outro
  JSON escapado como string. Foram abertas **17 strings JSON** entre **19
  entradas**, sem payload comprimido/Base64 no conjunto normal. Escapes de JSON
  não são criptografia. O DEFLATE/Base64 de `CloudCodec` é usado no transporte
  Firestore; o save local usual guarda o estado decodificado e `_sync` reduzido.
- Os UIDs e hashes das contas **não anonimizam** o arquivo. Um e-mail sintético
  digitado como **nome livre do mundo** apareceu na exportação, como esperado.
  Portanto, ausência de um campo `email` não garante ausência de dados pessoais.
- Houve um **teste adversarial separado**: foi inserida manualmente uma entrada
  sintética desconhecida contendo dados de teste em gzip + Base64. O exportador
  a incluiu intacta; a auditoria a decodificou e recuperou os marcadores. Isso
  comprova ausência de sanitização, **não que o jogo normalmente grave tokens**.
  Entradas históricas, importadas, inválidas ou alteradas manualmente não são
  validadas/redigidas na exportação. Não se pode garantir o conteúdo de todo
  backup antigo apenas pela revisão do produtor atual.

## Problema confirmado e recomendação

Conectado como a segunda conta, o arquivo continha os saves/catálogos das
**duas contas** do banco descartável. O código usa `scan` com prefixo vazio,
sem UID, confirmação de alcance ou remoção de identificadores. O carregamento
normal dos mundos continua validando o proprietário; o problema observado é
o alcance amplo e não anonimizado desta exportação manual, especialmente em
navegador compartilhado.

Guardar o JSON original como **backup privado**. Para suporte, compartilhar
somente por canal privado com destinatário de confiança e consentimento dos
demais titulares cujos dados possam estar no arquivo. Não publicar o JSON em
issue, rede social ou link aberto. Uma cópia reduzida/redigida para suporte
precisa de revisão do conteúdo interno, não apenas remoção dos campos externos;
preservar o original, pois redigir UID/ID pode impedir sua recuperação.

Não foi corrigido código de exportação, removido dado, alterada permissão,
aplicada regra Firebase ou publicada nova versão nesta auditoria. Possíveis
ajustes (exportação só da conta atual, aviso/consentimento e relatório mínimo
de suporte) ficam para avaliação do usuário.

## Reprodução técnica sem credenciais reais

`tools/audit-browser-save-export.mjs` usa o padrão Playwright dos testes locais
do projeto. Requer o Playwright já disponível em `.tools/browser-test` e Edge.
Executar `node tools/audit-browser-save-export.mjs` em ambiente isolado. Os
arquivos brutos são **somente sintéticos** e ficam ignorados em
`.tools/save-export-audit`; somente o resumo sem valores foi versionado.
O script não altera a função publicada nem injeta dados em um perfil pessoal.

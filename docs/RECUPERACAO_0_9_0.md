# Recuperação da 0.9.0 com saves v8

O cliente 0.9.0 e os pilotos .3/.4 leem **save 8, campanha 2 e tarefas 1**.
A 0.8.3 só lê até save 5; piloto .1 até 6; piloto .2 até 7.
O rollback apenas do aplicativo para 0.8.3 pode bloquear a abertura de mundos
novos. Não converta manualmente `version` nem remova campos do JSON para forçar
a leitura: isso não torna os dados compatíveis e pode perder conquistas.

## Preservar antes de agir

1. No endereço, navegador e perfil originais, entre na mesma conta e use
   **Menu → Exportar cópia dos saves deste navegador**. Guarde o JSON original
   em local privado; ele contém progresso e identificadores.
2. Se a interface não abrir, use o procedimento de leitura em
   [RECUPERAR_MUNDO.md](RECUPERAR_MUNDO.md), sem limpar cache/IndexedDB ou reinstalar.
   No nativo, copie a pasta `user://` inteira, incluindo catálogo, backups e
   metadados de sincronização.
3. Registre nome/ID do mundo, revisão remota confirmada e último estado conhecido.
   Preserve também qualquer cópia divergente antes de escolher uma versão.

## Recuperar o aplicativo

Republique o cliente **da tag `v0.9.0`** no mesmo Pages
`https://gustavotc-web.github.io/Tece-Island/`. O mesmo endereço conserva o acesso
ao IndexedDB existente; outra origem não herda os saves locais automaticamente.

Com autorização de manutenção, execute o workflow `pages.yml` usando a referência
da tag. O dispatch REST é:

```text
POST /repos/GustavoTc-Web/Tece-Island/actions/workflows/pages.yml/dispatches
{"ref":"v0.9.0"}
```

Esse workflow revalida o código, recompõe a build com as variáveis existentes e
publica sem operar o Firebase. Não substitua a lista de contas, não altere regras,
não habilite faturamento e não faça reset/force-push da main. Após o deploy,
confira `version.json`, o commit esperado, schemas 8/2/1 e SHA-256 de `index.pck`,
`index.js` e `index.wasm`. Preserve uma cópia dos arquivos/manifesto publicados.

Como alternativa de suporte, o piloto privado .4 e seu pacote nativo continuam
compatíveis com v8. Outra origem exige exportação/importação explícita ou uma
revisão de nuvem confirmada; não presuma que um mundo ausente nessa origem foi
apagado. Não execute clientes antigos simultaneamente sobre o mesmo mundo.

## Recuperar dados somente se necessário

Com cliente compatível aberto, confira primeiro o catálogo, os saves órfãos e as
revisões local/remota disponíveis. Para principal corrompido ou ausente, o lobby
oferece backups válidos e, quando habilitada, uma revisão remota validada. Compare
o resumo e escolha explicitamente; o original deve permanecer arquivado.

Backups `:before-v8` no IndexedDB e `.before-v8.json` no nativo são o estado
**anterior à migração**, não o último progresso da campanha. Restaurá-los pode
retroceder itens, templos e vitória do dia 7. Não os aplique automaticamente nem
envie um backup antigo por cima de uma revisão remota atual. Em conflito, preserve
ambas as versões e use a opção de cópia/continuação oferecida pelo jogo.

Sem save local, backup, exportação ou revisão remota válida, não há recuperação
garantida. Preserve a evidência disponível para diagnóstico; nunca crie um mundo
vazio no lugar de dados que ainda precisam ser examinados.

## Evidência desta versão

Foram preparados testes de gravação, fechamento e reabertura de cinco checkpoints
v8: mapa pendente, templo parcial, ataque interrompido, espera pelo amanhecer e
vitória no dia 7. Eles verificam conta/ID, bolsa, construções, conquistas, duas
reaberturas e codec de sincronização. A aplicação de um rollback em produção não
foi executada durante a publicação; permanece um procedimento de recuperação.

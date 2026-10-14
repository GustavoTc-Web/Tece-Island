# Obter os saves sem apagar armazenamento

Para a jogadora:

1. Abra o **mesmo endereço, navegador e perfil** usados na última partida, no
   aparelho original. Não limpe dados/cache, não reinstale e não crie outro mundo
   no lugar do desaparecido. Entre na mesma conta.
2. Na versão corrigida: Menu → **Exportar cópia dos saves deste navegador**.
   Guarde o JSON antes de escolher qualquer recuperação. Para versões antigas,
   peça ajuda para executar o arquivo abaixo nas ferramentas do navegador.
3. Informe aparelho/navegador, endereço exato do jogo, conta usada, nome do
   mundo, última ação antes de sumir e mensagem de erro, se houver. Senhas,
   tokens e links de login/recuperação não são necessários.

Para suporte no navegador original (computador ou depuração remota do celular):
abra DevTools → Console na página do jogo, leia e execute
[`tools/export-browser-saves.js`](../tools/export-browser-saves.js). O script usa
somente transações de leitura, exporta o banco por conta e bancos Godot `userfs`
legados e baixa `tece-island-diagnostico.json`. Não apaga nem migra dados. Se não
houver banco correspondente, o arquivo também registra isso.

Não publique o JSON em issue pública: ele contém progresso e identificadores
locais. Analise uma cópia, mantendo o arquivo original de exportação intacto.
No Godot nativo, copie a pasta `user://` da aplicação antes de inspecionar; no
Windows ela fica normalmente em `%APPDATA%/Godot/app_userdata/TC Island/`.

Diagnóstico:

| Evidência | Interpretação / ação |
| --- | --- |
| Save válido com ID ausente no catálogo | Mundo oculto: reconstruir catálogo conservando ID/dono |
| Principal inválido, backup válido | Recuperação explícita; arquivar principal antes de restaurar |
| Principal ausente, backup/temporário válido | Oferecer recuperação; não gerar mundo vazio |
| Nenhum dado neste perfil/origem, mas há no original | Ausência neste navegador; não declarar gravação perdida |
| Nenhum save/backup no navegador original | Investigar I/O, armazenamento removido, modo privado e última confirmação; não prometer recuperação |
| Dono/ID divergente ou duas versões válidas diferentes | Preservar ambas; não reatribuir a conta nem sobrescrever automaticamente |

A lista corrigida encontra saves órfãos. Ao tentar abrir um save quebrado, o
lobby oferece cópias válidas com resumo de itens, construções e registros. Escolha
a cópia após comparar; o arquivo quebrado é preservado. Se os dados só existirem
no aparelho original, exporte-os antes de atualizar ou tentar sincronizar.
Quando a sincronização estiver habilitada e houver conexão, o diálogo também
oferece uma versão remota validada, identificada pela revisão do serviço. Ela só
substitui o arquivo local depois da escolha do jogador e da cópia do original.

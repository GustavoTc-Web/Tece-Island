# Recuperação da beta solo: save v9

As oficiais **0.9.1-beta.1/2**, promovidas de suas candidatas, usam save **9**,
campanha **2**, tarefas **2**. A migração aceita saves
anteriores, preserva itens, mundo, conquistas e condições de vitória. Acrescenta
o registro de etapas concluídas/créditos de sono e o estado dos guardiões de
interiores (revelação, vida restante e derrotados). Migração não fabrica derrotas
antigas nem créditos de sono retroativos sem evidência registrada.

Antes de atualizar ou recuperar, exportar os dados pelo Menu do lobby, no mesmo
endereço, navegador, perfil e conta. A beta pública mantém a origem oficial
`https://gustavotc-web.github.io/Tece-Island/`; os dados locais existentes são
carregados e migrados nesse endereço. O Site privado da candidata é outra origem:
mundos locais de lá não aparecem automaticamente no endereço oficial. Para as
duas contas de sync os mundos remotos podem coincidir. Usar mundo novo para
retestes. Não abrir o mesmo mundo de nuvem simultaneamente em clientes v8 e v9.

Na primeira atualização de v8 para v9, o arquivo nativo preserva os bytes em
`.before-v9.json`. No Web/IndexedDB, a chave do mundo ganha `:before-v9`; os
backups `:backup`, `:backup-2`, anteriores e cópias de conflito são preservados.
As proteções de propriedade por UID/mundo, comparação da versão observada e
bloqueio de gravação em arquivo incompatível continuam em vigor.

Se houver problema:

1. Parar de editar o mundo e exportar dados/diagnóstico. Não limpar o site,
   apagar IndexedDB, importar em outra conta nem mudar `version` no JSON.
2. Republicar um cliente corrigido **compatível com v9**, no mesmo endereço,
   e abrir com o mesmo perfil e UID. Conservar originais e backups antes de usar
   a recuperação já existente no Menu. Preferir abrir como cópia quando houver
   conflito para não substituir a outra sessão.
3. Se for indispensável retornar ao cliente antigo, restaurar explicitamente
   uma cópia v8 anterior à migração pelo procedimento de recuperação e somente
   então usar um cliente v8. Isso perde as ações posteriores ao backup escolhido;
   preservar também o v9 para futura recuperação compatível.

**0.9.0 e RC1 não abrem v9.** Republicar apenas a 0.8.3, 0.9.0 ou RC1 sobre um
save já convertido não é recuperação. O cliente antigo deve recusá-lo e manter
o original; não se deve contornar essa proteção editando a versão do save.

O pacote Web desta beta será preservado como arquivo de recuperação na
[release v0.9.1-beta.2](https://github.com/GustavoTc-Web/Tece-Island/releases/tag/v0.9.1-beta.2).
Ele contém o aplicativo, não os saves. Conferir o SHA-256 no registro da
[publicação](PUBLICACAO_0_9_1_BETA_2.md). Uma restauração operacional deve servir
esse cliente **no mesmo endereço/origem**, mediante autorização; abrir o arquivo
em outra origem não recupera o IndexedDB original. A opção preferida continua
sendo corrigir e republicar um cliente v9, preservando os dados existentes.

Complementos: [exportação e recuperação](RECUPERAR_MUNDO.md),
[recuperação da oficial v8](RECUPERACAO_0_9_0.md).

# Recuperação da beta RC2: save v9

A RC2 usa save **9**, campanha **2**, tarefas **2**. A migração aceita saves
anteriores, preserva itens, mundo, conquistas e condições de vitória. Acrescenta
o registro de etapas concluídas/créditos de sono e o estado dos guardiões de
interiores (revelação, vida restante e derrotados). Migração não fabrica derrotas
antigas nem créditos de sono retroativos sem evidência registrada.

Antes de testar, exportar os dados pelo Menu do lobby, no mesmo endereço,
navegador, perfil e conta. A candidata tem origem separada da oficial; para as
duas contas de sync os mundos remotos podem coincidir. Preferir mundo novo de
teste. Não abrir o mesmo mundo de nuvem simultaneamente na oficial v8 e na RC2.

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

Complementos: [exportação e recuperação](RECUPERAR_MUNDO.md),
[recuperação da oficial v8](RECUPERACAO_0_9_0.md).

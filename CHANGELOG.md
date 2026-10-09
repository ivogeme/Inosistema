CHANGELOG

Todas as mudanças relevantes do Inosistema serão registradas neste arquivo.

[0.1.0-prototype] - Em desenvolvimento

Primeiro protótipo público do Inosistema.

História do projeto

O Inosistema surgiu originalmente como uma ideia de sistema operacional baseado em Linux, voltado para computadores antigos. Durante o desenvolvimento do conceito, surgiu a percepção de que mesmo uma distribuição Linux enxuta não atendia plenamente ao objetivo de construir uma base extremamente pequena para hardware muito limitado.

O projeto evoluiu, então, para a ideia de desenvolver um núcleo próprio, escrito principalmente em C, com Assembly na etapa de inicialização.

A proposta passou a ser explorar uma arquitetura simples, independente de uma distribuição Linux, começando pelo ambiente x86 em modo real e tendo os computadores IBM PC antigos como referência de longo prazo.

Implementado ou presente no código

- Bootloader em Assembly para carregar o núcleo.
- Ponto de entrada em Assembly que chama o código C.
- Configuração da comunicação serial COM1.
- Shell serial com comandos básicos.
- Estrutura inicial de compilação com Makefile e linker script.

Limitações conhecidas

- A compilação completa ainda precisa ser verificada.
- A inicialização no QEMU ainda precisa ser testada.
- A compatibilidade com o IBM PC 5150 e o processador Intel 8088 não foi confirmada.
- O sistema de arquivos persistente ainda não foi implementado.
- A leitura e gravação reais de arquivos ainda não estão implementadas.
- A execução de programas carregados do disco ainda não foi validada.

Próximos passos

1. Corrigir e revisar os arquivos de inicialização.
2. Compilar o projeto e corrigir eventuais erros.
3. Testar a imagem no QEMU.
4. Confirmar a comunicação serial e o funcionamento do shell.
5. Planejar o acesso ao disco e um sistema de arquivos próprio.

Nota: esta entrada documenta o estado inicial do protótipo. Os itens serão atualizados conforme forem compilados, testados e implementados.
# TikTok LIVE Arena — Brasília em Disputa

Jogo HTML interativo de sátira política brasileira para TikTok LIVE. A comunidade escolhe um lado do debate humorístico entre Lula e Bolsonaro e os eventos recebidos podem alterar o placar. Projeto independente, com conector comunitário não oficial.

## Abrir o jogo
- Hospedagem: https://tiktok-live-arena.onrender.com
- Saúde do servidor: https://tiktok-live-arena.onrender.com/health
- Código: https://github.com/NANDOBRTV/tiktok-live-arena

## Como testar pelo Android
1. Abra a página do jogo no navegador.
2. Inicie uma LIVE pública no TikTok e informe seu nome de usuário público (não informe senha).
3. Toque em **Conectar LIVE**.
4. Confira o estado da conexão e os eventos no painel.
5. Comandos: `!lula` apoia o lado Lula; `!bolsonaro` apoia o lado Bolsonaro; `!debate` provoca uma reviravolta humorística. Curtidas e presentes somam pontos ao lado escolhido mais recentemente pelo espectador, quando o evento é recebido e identificado pelo conector. Use **Testar animação local** para conferir a interface sem uma LIVE real.

## Desenvolvimento local
Requer Node.js 20 ou superior.

```bash
npm install
npm start
``

Abra `http://localhost:3000`. O endpoint `/health` indica se o servidor está funcionando.

## Observações e limitações
- O conector `tiktok-live-connector` é não oficial e reverso-engenheirado. Pode parar de funcionar se o TikTok mudar o protocolo, e a conexão depende de uma LIVE pública acessível.
- Hospedagem gratuita pode suspender o serviço por inatividade; a primeira abertura pode demorar.
- A implantação hospedada ainda precisa ser verificada e os eventos reais precisam ser testados em uma LIVE. O botão de teste local não confirma integração real.
- Este projeto não garante renda nem converte presentes em pagamentos. Os presentes são eventos informativos recebidos do TikTok; a monetização depende das regras e dos recursos oficiais da plataforma.
- Nunca coloque senhas, cookies ou tokens privados no GitHub. A página pede somente o nome de usuário público.
- Para transmitir o jogo na LIVE pelo mesmo Android, use a função de jogos/compartilhamento de tela liberada na sua conta. O comportamento ao alternar entre TikTok e navegador varia conforme aparelho e versão do aplicativo.

## Privacidade
O servidor transmite eventos recebidos para os navegadores conectados ao jogo. Nomes de usuário e mensagens podem aparecer na arena. Use somente para uma LIVE que você tem autorização para acompanhar.

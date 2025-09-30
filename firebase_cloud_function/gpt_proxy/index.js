const functions = require('@google-cloud/functions-framework');
const cors = require('cors')({ origin: true });

/**
 * GPT Proxy Cloud Function
 * 支援串流和非串流請求
 */
functions.http('chatProxy', (req, res) => {
  cors(req, res, async () => {
      // 只允許 POST 請求
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      try {
        const { model, messages, temperature, stream, tools, tool_choice, stream_options } = req.body;

        // 驗證必要參數
        if (!model || !messages) {
          res.status(400).json({ error: 'Missing required parameters: model and messages' });
          return;
        }

        // 準備請求體
        const requestBody = {
          model,
          messages,
          temperature: temperature || 0.7,
          stream: stream || false
        };

        // 添加可選參數
        if (tools) requestBody.tools = tools;
        if (tool_choice) requestBody.tool_choice = tool_choice;
        if (stream_options) requestBody.stream_options = stream_options;

        // 呼叫 OpenAI API
        const fetch = (await import('node-fetch')).default;
        const response = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
          },
          body: JSON.stringify(requestBody)
        });

        if (!response.ok) {
          const errorData = await response.text();
          console.error('OpenAI API error:', errorData);
          res.status(response.status).json({
            error: 'OpenAI API error',
            details: errorData
          });
          return;
        }

        // 如果是串流請求
        if (stream) {
          res.writeHead(200, {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'Access-Control-Allow-Origin': '*'
          });

          // 轉發串流資料
          response.body.on('data', (chunk) => {
            res.write(chunk);
          });

          response.body.on('end', () => {
            res.end();
          });

          response.body.on('error', (error) => {
            console.error('Stream error:', error);
            res.end();
          });
        } else {
          // 非串流請求
          const data = await response.json();
          res.status(200).json(data);
        }
      } catch (error) {
        console.error('Error in gptProxy:', error);
        res.status(500).json({
          error: 'Internal server error',
          message: error.message
        });
      }
    });
});
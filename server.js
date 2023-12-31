const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());

// Serve static assets from the 'dist' directory
app.use(express.static(path.join(__dirname, 'dist')));

app.get ('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
})

// Start the server
app.listen(PORT, () => {
  console.log(`Server is listening on port ${PORT}`);
});

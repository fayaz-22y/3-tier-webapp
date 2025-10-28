clear
ls
sudo apt update && sudo apt upgrade -y 
sudo init6
sudo init 6
clear
ls
# Create project directory
mkdir -p ~/ecommerce-app/backend/src/{config,routes}
cd ~/ecommerce-app/backend
ls
cat > .env << 'EOF'
PORT=5000
DATABASE_URL=postgresql://postgres:yourpassword@localhost:5432/ecommerce_db
JWT_SECRET=mysecretkey12345changethisinproduction
NODE_ENV=development
EOF

vi .env 
cat > package.json << 'EOF'
{
  "name": "ecommerce-backend",
  "version": "1.0.0",
  "description": "E-commerce backend API",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# Install dependencies
npm install
sudo apt install npm
cat > src/config/database.js << 'EOF'
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

pool.connect((err, client, release) => {
  if (err) {
    console.error('Error connecting to the database:', err.stack);
  } else {
    console.log('✅ Database connected successfully');
    release();
  }
});

module.exports = pool;
EOF

cat > src/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const productRoutes = require('./routes/productRoutes');
const userRoutes = require('./routes/userRoutes');
const orderRoutes = require('./routes/orderRoutes');
const cartRoutes = require('./routes/cartRoutes');

app.use('/api/products', productRoutes);
app.use('/api/users', userRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/cart', cartRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'E-commerce API is running' });
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
EOF

cat > src/routes/productRoutes.js << 'EOF'
const express = require('express');
const router = express.Router();
const pool = require('../config/database');

router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM products WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch product' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { name, description, price, stock_quantity, category, image_url } = req.body;
    const result = await pool.query(
      'INSERT INTO products (name, description, price, stock_quantity, category, image_url) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [name, description, price, stock_quantity, category, image_url]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to create product' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, price, stock_quantity, category, image_url } = req.body;
    const result = await pool.query(
      'UPDATE products SET name = $1, description = $2, price = $3, stock_quantity = $4, category = $5, image_url = $6, updated_at = CURRENT_TIMESTAMP WHERE id = $7 RETURNING *',
      [name, description, price, stock_quantity, category, image_url, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update product' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING *', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to delete product' });
  }
});

module.exports = router;
EOF

cat > src/routes/userRoutes.js << 'EOF'
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/database');

router.post('/register', async (req, res) => {
  try {
    const { username, email, password, first_name, last_name, phone } = req.body;
    
    const userExists = await pool.query('SELECT * FROM users WHERE email = $1 OR username = $2', [email, username]);
    if (userExists.rows.length > 0) {
      return res.status(400).json({ error: 'User already exists' });
    }
    
    const hashedPassword = await bcrypt.hash(password, 10);
    
    const result = await pool.query(
      'INSERT INTO users (username, email, password, first_name, last_name, phone) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, username, email, first_name, last_name',
      [username, email, hashedPassword, first_name, last_name, phone]
    );
    
    const token = jwt.sign({ id: result.rows[0].id }, process.env.JWT_SECRET, { expiresIn: '7d' });
    
    res.status(201).json({ user: result.rows[0], token });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to register user' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const user = result.rows[0];
    
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: '7d' });
    
    res.json({ 
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name
      }, 
      token 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to login' });
  }
});

router.get('/profile/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT id, username, email, first_name, last_name, phone FROM users WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});

module.exports = router;
EOF

cat > src/routes/orderRoutes.js << 'EOF'
const express = require('express');
const router = express.Router();
const pool = require('../config/database');

router.post('/', async (req, res) => {
  const client = await pool.connect();
  try {
    const { user_id, items, shipping_address } = req.body;
    
    await client.query('BEGIN');
    
    let total = 0;
    for (const item of items) {
      const productResult = await client.query('SELECT price FROM products WHERE id = $1', [item.product_id]);
      total += productResult.rows[0].price * item.quantity;
    }
    
    const orderResult = await client.query(
      'INSERT INTO orders (user_id, total_amount, shipping_address) VALUES ($1, $2, $3) RETURNING *',
      [user_id, total, shipping_address]
    );
    
    const orderId = orderResult.rows[0].id;
    
    for (const item of items) {
      const productResult = await client.query('SELECT price, stock_quantity FROM products WHERE id = $1', [item.product_id]);
      const product = productResult.rows[0];
      
      if (product.stock_quantity < item.quantity) {
        throw new Error(`Insufficient stock for product ${item.product_id}`);
      }
      
      await client.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4)',
        [orderId, item.product_id, item.quantity, product.price]
      );
      
      await client.query(
        'UPDATE products SET stock_quantity = stock_quantity - $1 WHERE id = $2',
        [item.quantity, item.product_id]
      );
    }
    
    await client.query('COMMIT');
    res.status(201).json(orderResult.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(error);
    res.status(500).json({ error: error.message || 'Failed to create order' });
  } finally {
    client.release();
  }
});

router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await pool.query(
      `SELECT o.*, json_agg(json_build_object('product_id', oi.product_id, 'quantity', oi.quantity, 'price', oi.price, 'name', p.name)) as items
       FROM orders o
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       WHERE o.user_id = $1
       GROUP BY o.id
       ORDER BY o.created_at DESC`,
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `SELECT o.*, json_agg(json_build_object('product_id', oi.product_id, 'quantity', oi.quantity, 'price', oi.price, 'name', p.name)) as items
       FROM orders o
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       WHERE o.id = $1
       GROUP BY o.id`,
      [id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch order' });
  }
});

module.exports = router;
EOF

cat > src/routes/cartRoutes.js << 'EOF'
const express = require('express');
const router = express.Router();
const pool = require('../config/database');

router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await pool.query(
      `SELECT c.id, c.user_id, c.product_id, c.quantity, 
              p.name, p.price, p.image_url, p.stock_quantity
       FROM cart c
       JOIN products p ON c.product_id = p.id
       WHERE c.user_id = $1
       ORDER BY c.created_at DESC`,
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch cart' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { user_id, product_id, quantity } = req.body;
    
    const productResult = await pool.query('SELECT stock_quantity FROM products WHERE id = $1', [product_id]);
    if (productResult.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    const stock = productResult.rows[0].stock_quantity;
    if (stock < quantity) {
      return res.status(400).json({ error: 'Insufficient stock' });
    }
    
    const existingItem = await pool.query(
      'SELECT * FROM cart WHERE user_id = $1 AND product_id = $2',
      [user_id, product_id]
    );
    
    if (existingItem.rows.length > 0) {
      const newQuantity = existingItem.rows[0].quantity + quantity;
      if (newQuantity > stock) {
        return res.status(400).json({ error: 'Cannot add more than available stock' });
      }
      
      const result = await pool.query(
        'UPDATE cart SET quantity = $1 WHERE user_id = $2 AND product_id = $3 RETURNING *',
        [newQuantity, user_id, product_id]
      );
      res.json(result.rows[0]);
    } else {
      const result = await pool.query(
        'INSERT INTO cart (user_id, product_id, quantity) VALUES ($1, $2, $3) RETURNING *',
        [user_id, product_id, quantity]
      );
      res.status(201).json(result.rows[0]);
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to add to cart' });
  }
});

router.put('/:cartId', async (req, res) => {
  try {
    const { cartId } = req.params;
    const { quantity } = req.body;
    
    if (quantity < 1) {
      return res.status(400).json({ error: 'Quantity must be at least 1' });
    }
    
    const cartItem = await pool.query(
      `SELECT c.*, p.stock_quantity 
       FROM cart c 
       JOIN products p ON c.product_id = p.id 
       WHERE c.id = $1`,
      [cartId]
    );
    
    if (cartItem.rows.length === 0) {
      return res.status(404).json({ error: 'Cart item not found' });
    }
    
    if (quantity > cartItem.rows[0].stock_quantity) {
      return res.status(400).json({ error: 'Quantity exceeds available stock' });
    }
    
    const result = await pool.query(
      'UPDATE cart SET quantity = $1 WHERE id = $2 RETURNING *',
      [quantity, cartId]
    );
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update cart' });
  }
});

router.delete('/:cartId', async (req, res) => {
  try {
    const { cartId } = req.params;
    const result = await pool.query('DELETE FROM cart WHERE id = $1 RETURNING *', [cartId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Cart item not found' });
    }
    res.json({ message: 'Item removed from cart' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to remove item' });
  }
});

router.delete('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    await pool.query('DELETE FROM cart WHERE user_id = $1', [userId]);
    res.json({ message: 'Cart cleared' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to clear cart' });
  }
});

module.exports = router;
EOF

cat > schema.sql << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    category VARCHAR(100),
    image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    shipping_address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cart (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id)
);

INSERT INTO products (name, description, price, stock_quantity, category, image_url) VALUES
('Laptop Pro 15"', 'High-performance laptop with 16GB RAM and 512GB SSD, perfect for professionals', 999.99, 50, 'Electronics', 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=500'),
('Smartphone X', 'Latest model with 128GB storage, 5G capable, stunning AMOLED display', 699.99, 100, 'Electronics', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500'),
('Wireless Headphones', 'Premium noise-canceling headphones with 30-hour battery life', 199.99, 75, 'Electronics', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500'),
('Smart Watch', 'Fitness tracker with heart rate monitor and GPS', 299.99, 60, 'Electronics', 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500'),
('4K Monitor', '27-inch 4K UHD display with HDR support', 399.99, 40, 'Electronics', 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=500'),
('Cotton T-Shirt', 'Premium quality 100% cotton t-shirt available in multiple colors', 29.99, 200, 'Clothing', 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500'),
('Denim Jeans', 'Classic fit denim jeans with stretch fabric', 59.99, 150, 'Clothing', 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=500'),
('Running Shoes', 'Lightweight running shoes with cushioned sole', 89.99, 120, 'Footwear', 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500'),
('Backpack', 'Durable travel backpack with laptop compartment', 79.99, 80, 'Accessories', 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500'),
('Coffee Maker', 'Programmable coffee maker with thermal carafe', 129.99, 45, 'Home & Kitchen', 'https://images.unsplash.com/photo-1517668808822-9ebb02f2a0e6?w=500');
EOF

# Run schema
sudo -u postgres psql -d ecommerce_db -f schema.sql
# Start backend with PM2
pm2 start src/server.js --name ecommerce-backend
pm2 save
cat schema.sql 
sudo -u postgres psql -d ecommerce_db -f schema.sql
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs build-essential
sudo apt install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'fayaz';"
cd ..
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'fayaz';"
sudo systemctl enable postgresql
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'fayaz';"
cat .env 
cd backend/
ls
car .env 
cat .env 
sudo -u postgres psql -d ecommerce_db -f schema.sql
clear
ls
cd 
ls
rm -f ecommerce-app/
ls
rm -rf ecommerce-app/
ls
clear
ls
clear
l
la
ls
clear
ls
sudo -i -u postgres
psql
ALTER USER postgres PASSWORD 'admin123';
\q
exit
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo -i -u postgres
sudo vim /etc/postgresql/14/main/postgresql.conf
sudo vim /etc/postgresql/14/main/pg_hba.conf
sudo systemctl restart postgresql
curl https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo apt-key add -
sudo sh -c 'echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/jammy pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list && apt update'
sudo apt install pgadmin4-web -y
sudo /usr/pgadmin4/bin/setup-web.sh
curl http://34.228.158.202:5050
sudo systemctl status apache2
sudo ls /usr/pgadmin4/
sudo ss -tuln | grep 5050
sudo /usr/pgadmin4/bin/setup-web.sh
sudo systemctl restart apache2
sudo systemctl restart postgresql
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
node -v 
npm -v 
sudo apt install npm 
mkdir ecommerce-backend && cd ecommerce-backend
npm init -y 
npm install express pg cors dotenv
npm install --save-dev nodemon
touch index.js .env
mkdir routes
touch routes/products.js
vi index.js 
vi .env 
sudo -i -u postgres
npx nodemon index.js
vim package.json 
npx nodem index.js
npx nodemon index.js
node -v 
sudo apt remove -y nodejs
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node -v 
sudo apt install -y nodejs
node -v 
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo apt remove -y nodejs
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node -v 
sudo apt purge -y nodejs libnode-dev
sudo apt autoremove -y
sudo rm -rf /usr/local/lib/node_modules
sudo rm -f /usr/bin/node /usr/bin/npm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node -v 
npm -v 
rm -rf node_modules package-lock.json
npm install
npx nodemon index.js
sudo -i -u postgres
npx nodemon index.js
cd ~
npx create-react-app ecommerce-frontend
cd ecommerce-frontend
npm install axios
vi src/App.js 
npm start
curl http://34.228.158.202:3000/
curl http://34.228.158.202:3000
vi src/App.js 
npm start
vi src/App.
ls
cd ecommerce-backend/
npx nodemon index.js
sudo service postgresql start
curl http://localhost:5000/api/products
ls
cd ecommerce-
cd ecommerce-frontend/
ls
vi src/App.js 
npm run build 
pgadmin start 
cd ..
cd ecommerce-backend/
ls
pgadmin start
vi /etc/postgresql/<version>/main/postgresql.conf
cd ..
vi /etc/postgresql/<version>/main/postgresql.conf
cd ecommerce-backend/
ls
cd routes/
ls
cat products.js 
ls
cd ..
cd node_modules/
ls
cd ..
cd ecommerce-frontend/
vi src/App.
rm src/App.
vi src/App.js 
cd ..
git --version 
ls
sudo apt install tree
ls
tree
ls
cd ecommerce-
cd ecommerce-backend/
ls
npx nodemon index.js 
cd ecommerce-frontend/
npm start

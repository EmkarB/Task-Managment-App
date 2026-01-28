import { useState, FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import './Login.css';

export function Login() {
  const [isRegister, setIsRegister] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  
  const { login, register, error } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setSuccessMessage('');

    if (isRegister) {
      const success = await register(email, password);
      if (success) {
        setSuccessMessage('Registration successful! Please login.');
        setIsRegister(false);
        setPassword('');
      }
    } else {
      const success = await login(email, password);
      if (success) {
        navigate('/tasks');
      }
    }

    setLoading(false);
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-header">
          <h1>Task Manager</h1>
          <p>{isRegister ? 'Create your account' : 'Welcome back'}</p>
        </div>

        <form onSubmit={handleSubmit} className="login-form">
          <div className="form-group">
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Enter your email"
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter your password"
              minLength={6}
              required
            />
          </div>

          {error && <div className="error-message">{error}</div>}
          {successMessage && <div className="success-message">{successMessage}</div>}

          <button type="submit" className="submit-btn" disabled={loading}>
            {loading ? 'Please wait...' : isRegister ? 'Register' : 'Login'}
          </button>
        </form>

        <div className="login-footer">
          <button
            type="button"
            className="toggle-btn"
            onClick={() => {
              setIsRegister(!isRegister);
              setSuccessMessage('');
            }}
          >
            {isRegister ? 'Already have an account? Login' : "Don't have an account? Register"}
          </button>
        </div>
      </div>
    </div>
  );
}

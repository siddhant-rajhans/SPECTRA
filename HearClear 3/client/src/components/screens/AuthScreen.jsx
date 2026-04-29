import React, { useState } from 'react'
import { loginUser, signupUser } from '../../services/api'

// Auralis SVG Logo Component
function AuralisLogo({ size = 72 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
      {/* Outer ring - gradient */}
      <defs>
        <linearGradient id="logoGrad" x1="0" y1="0" x2="120" y2="120" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stopColor="#6366F1" />
          <stop offset="50%" stopColor="#8B5CF6" />
          <stop offset="100%" stopColor="#0EA5E9" />
        </linearGradient>
        <linearGradient id="innerGrad" x1="20" y1="20" x2="100" y2="100" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stopColor="#818CF8" />
          <stop offset="100%" stopColor="#38BDF8" />
        </linearGradient>
      </defs>
      <circle cx="60" cy="60" r="58" stroke="url(#logoGrad)" strokeWidth="3" fill="none" opacity="0.3" />
      <circle cx="60" cy="60" r="48" fill="url(#logoGrad)" />
      {/* Sound wave arcs - representing hearing */}
      <path d="M50 42C56 36 64 36 70 42" stroke="white" strokeWidth="2.5" strokeLinecap="round" fill="none" />
      <path d="M44 36C54 26 66 26 76 36" stroke="white" strokeWidth="2" strokeLinecap="round" fill="none" opacity="0.7" />
      <path d="M38 30C52 16 68 16 82 30" stroke="white" strokeWidth="1.5" strokeLinecap="round" fill="none" opacity="0.4" />
      {/* Ear silhouette - simplified */}
      <path d="M55 48C50 52 48 60 50 68C52 76 56 80 60 82C64 80 68 76 70 68C72 60 70 52 65 48C62 46 58 46 55 48Z"
        fill="white" opacity="0.95" />
      <circle cx="60" cy="64" r="4" fill="url(#innerGrad)" />
    </svg>
  )
}

export function AuthScreen({ onLogin }) {
  const [mode, setMode] = useState('signin')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [formData, setFormData] = useState({
    name: '', email: '', password: '', confirmPassword: '',
    hearingLossLevel: '', deviceBrand: '', deviceModel: ''
  })

  const handleInputChange = (e) => {
    setFormData(prev => ({ ...prev, [e.target.name]: e.target.value }))
    setError(null)
  }

  const validateSignIn = () => {
    if (!formData.email || !formData.password) { setError('Email and password are required'); return false }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) { setError('Please enter a valid email'); return false }
    return true
  }

  const validateSignUp = () => {
    if (!formData.name || !formData.email || !formData.password || !formData.confirmPassword) {
      setError('Please fill in all required fields'); return false
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) { setError('Please enter a valid email'); return false }
    if (formData.password.length < 6) { setError('Password must be at least 6 characters'); return false }
    if (formData.password !== formData.confirmPassword) { setError('Passwords do not match'); return false }
    if (!formData.hearingLossLevel) { setError('Please select your hearing loss level'); return false }
    if (!formData.deviceBrand) { setError('Please select your device brand'); return false }
    return true
  }

  const handleSignIn = async (e) => {
    e.preventDefault()
    if (!validateSignIn()) return
    setLoading(true)
    try {
      const result = await loginUser(formData.email, formData.password)
      onLogin(result.user)
    } catch (err) { setError(err.message) }
    finally { setLoading(false) }
  }

  const handleSignUp = async (e) => {
    e.preventDefault()
    if (!validateSignUp()) return
    setLoading(true)
    try {
      const result = await signupUser({
        name: formData.name, email: formData.email, password: formData.password,
        hearingLossLevel: formData.hearingLossLevel, deviceBrand: formData.deviceBrand,
        deviceModel: formData.deviceModel || null
      })
      onLogin(result.user)
    } catch (err) { setError(err.message) }
    finally { setLoading(false) }
  }

  const resetForm = () => {
    setFormData({ name: '', email: '', password: '', confirmPassword: '', hearingLossLevel: '', deviceBrand: '', deviceModel: '' })
    setError(null)
  }

  const handleModeChange = (newMode) => { setMode(newMode); resetForm() }

  return (
    <div className="auth-screen">
      {/* Logo */}
      <div className="auth-logo-area">
        <AuralisLogo size={80} />
      </div>

      <h1 className="auth-title">Auralis</h1>
      <p className="auth-subtitle">Context-Aware Hearing Companion</p>

      {/* Toggle */}
      <div className="auth-toggle">
        <button className={`auth-toggle-btn ${mode === 'signin' ? 'active' : ''}`} onClick={() => handleModeChange('signin')}>Sign In</button>
        <button className={`auth-toggle-btn ${mode === 'signup' ? 'active' : ''}`} onClick={() => handleModeChange('signup')}>Sign Up</button>
      </div>

      {/* Sign In */}
      {mode === 'signin' && (
        <form className="auth-form" onSubmit={handleSignIn}>
          <div className="auth-field">
            <label className="auth-label">Email</label>
            <div className="auth-input-wrapper">
              <span className="auth-input-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
              </span>
              <input className="auth-input" type="email" name="email" placeholder="you@example.com" value={formData.email} onChange={handleInputChange} disabled={loading} />
            </div>
          </div>
          <div className="auth-field">
            <label className="auth-label">Password</label>
            <div className="auth-input-wrapper">
              <span className="auth-input-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
              </span>
              <input className="auth-input" type="password" name="password" placeholder="Enter your password" value={formData.password} onChange={handleInputChange} disabled={loading} />
            </div>
          </div>
          {error && <div className="auth-error">{error}</div>}
          <button className="auth-btn" type="submit" disabled={loading}>
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
          <div className="auth-forgot">Forgot password?</div>
        </form>
      )}

      {/* Sign Up */}
      {mode === 'signup' && (
        <form className="auth-form" onSubmit={handleSignUp}>
          <div className="auth-field">
            <label className="auth-label">Full Name</label>
            <div className="auth-input-wrapper">
              <span className="auth-input-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/></svg>
              </span>
              <input className="auth-input" type="text" name="name" placeholder="Your full name" value={formData.name} onChange={handleInputChange} disabled={loading} />
            </div>
          </div>
          <div className="auth-field">
            <label className="auth-label">Email</label>
            <div className="auth-input-wrapper">
              <span className="auth-input-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
              </span>
              <input className="auth-input" type="email" name="email" placeholder="you@example.com" value={formData.email} onChange={handleInputChange} disabled={loading} />
            </div>
          </div>
          <div className="auth-field">
            <label className="auth-label">Password</label>
            <div className="auth-input-wrapper">
              <span className="auth-input-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
              </span>
              <input className="auth-input" type="password" name="password" placeholder="Min 6 characters" value={formData.password} onChange={handleInputChange} disabled={loading} />
            </div>
          </div>
          <div className="auth-field">
            <label className="auth-label">Confirm Password</label>
            <div className="auth-input-wrapper">
              <span className="auth-input-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
              </span>
              <input className="auth-input" type="password" name="confirmPassword" placeholder="Repeat password" value={formData.confirmPassword} onChange={handleInputChange} disabled={loading} />
            </div>
          </div>
          <div className="auth-field">
            <label className="auth-label">Hearing Loss Level</label>
            <select className="auth-select" name="hearingLossLevel" value={formData.hearingLossLevel} onChange={handleInputChange} disabled={loading}>
              <option value="">Select your level...</option>
              <option value="mild">Mild</option>
              <option value="moderate">Moderate</option>
              <option value="severe">Severe</option>
              <option value="profound">Profound</option>
              <option value="unsure">I'm not sure</option>
            </select>
          </div>
          <div className="auth-field">
            <label className="auth-label">Device Brand</label>
            <select className="auth-select" name="deviceBrand" value={formData.deviceBrand} onChange={handleInputChange} disabled={loading}>
              <option value="">Select a brand...</option>
              <option value="Cochlear">Cochlear</option>
              <option value="Phonak">Phonak</option>
              <option value="Oticon">Oticon</option>
              <option value="ReSound">ReSound</option>
              <option value="Starkey">Starkey</option>
              <option value="Widex">Widex</option>
              <option value="MED-EL">MED-EL</option>
              <option value="Other">Other</option>
            </select>
          </div>
          <div className="auth-field">
            <label className="auth-label">Device Model (Optional)</label>
            <div className="auth-input-wrapper">
              <span className="auth-input-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="22"/></svg>
              </span>
              <input className="auth-input" type="text" name="deviceModel" placeholder="e.g., Nucleus 8" value={formData.deviceModel} onChange={handleInputChange} disabled={loading} />
            </div>
          </div>
          {error && <div className="auth-error">{error}</div>}
          <button className="auth-btn" type="submit" disabled={loading}>
            {loading ? 'Creating Account...' : 'Create Account'}
          </button>
        </form>
      )}

      {/* Footer */}
      <div className="auth-footer">
        <div>Stevens Institute of Technology</div>
        <div>CS545B · Bridging the Gap</div>
      </div>
    </div>
  )
}

import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { Layout } from '@/components/layout/Layout'
import { Generator } from '@/pages/Generator'
import { Dashboard } from '@/pages/Dashboard'
import { LinkDetail } from '@/pages/LinkDetail'

export function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Generator />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="dashboard/:token" element={<LinkDetail />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

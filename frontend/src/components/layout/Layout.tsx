import { useState } from 'react'
import { Outlet } from 'react-router-dom'
import { Header } from './Header'
import { Sidebar } from './Sidebar'

export function Layout() {
  const [desktopOpen, setDesktopOpen] = useState(true)
  const [mobileOpen, setMobileOpen] = useState(false)

  function handleToggleSidebar() {
    if (window.innerWidth < 768) {
      setMobileOpen((prev) => !prev)
    } else {
      setDesktopOpen((prev) => !prev)
    }
  }

  return (
    <div className="flex flex-col h-screen">
      <Header onToggleSidebar={handleToggleSidebar} />
      <div className="flex flex-1 overflow-hidden relative">
        {/* Mobile backdrop */}
        <div
          className={[
            'fixed inset-0 bg-black/40 z-40 md:hidden transition-opacity duration-200',
            mobileOpen ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none',
          ].join(' ')}
          onClick={() => setMobileOpen(false)}
        />

        <Sidebar
          desktopOpen={desktopOpen}
          mobileOpen={mobileOpen}
          onMobileClose={() => setMobileOpen(false)}
        />

        <main className="flex-1 overflow-auto">
          <div className="mx-auto max-w-[1200px] w-full p-4 md:p-6">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  )
}

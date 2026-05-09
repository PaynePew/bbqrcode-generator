import { NavLink } from 'react-router-dom'
import { QrCode, LayoutDashboard } from 'lucide-react'
import { cn } from '@/lib/utils'

const navItems = [
  { to: '/', label: '產生器', icon: QrCode, end: true },
  { to: '/dashboard', label: '儀表板', icon: LayoutDashboard, end: false },
]

interface SidebarProps {
  desktopOpen: boolean
  mobileOpen: boolean
  onMobileClose: () => void
}

export function Sidebar({ desktopOpen, mobileOpen, onMobileClose }: SidebarProps) {
  return (
    <aside
      className={cn(
        'flex flex-col border-r bg-sidebar shrink-0 overflow-hidden',
        // Mobile: fixed overlay panel, slide in/out via transform
        'fixed top-14 bottom-0 z-50 w-52 transition-transform duration-200',
        mobileOpen ? 'translate-x-0' : '-translate-x-full',
        // Desktop: inline, controlled by width
        'md:relative md:top-auto md:bottom-auto md:z-auto',
        'md:translate-x-0 md:transition-all md:duration-200',
        desktopOpen ? 'md:w-52' : 'md:w-0 md:border-r-0',
      )}
      aria-hidden={!desktopOpen && !mobileOpen}
    >
      <nav className="flex flex-col gap-1 p-2 pt-3 w-52">
        {navItems.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            onClick={onMobileClose}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-sidebar-accent text-sidebar-accent-foreground'
                  : 'text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground',
              )
            }
          >
            <Icon className="h-4 w-4 shrink-0" />
            {label}
          </NavLink>
        ))}
      </nav>
    </aside>
  )
}

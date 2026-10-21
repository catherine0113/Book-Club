import './globals.css';
import Link from 'next/link';
export const metadata={title:'Books, Wishes & Serendipity',description:'A little reading. A little wishing. A lovely afternoon together.'};
export default function Layout({children}){return <html lang="zh-Hant"><body><header><Link className="brand" href="/">bws<span>THE BOOK CLUB</span></Link><nav><Link href="/#how">How it works</Link><Link href="/register" className="small-button">Join the club ↗</Link></nav></header>{children}<footer><div className="brand">Books, Wishes & Serendipity</div><p>Good books. Thoughtful gifts. Unexpected connections.</p><Link href="/admin">For the organizers ↗</Link><small>Made for a lovely afternoon in Taipei.</small></footer></body></html>}

import RegistrationForm from '../../register/form';
export default async function Page({params}){const {token}=await params;return <RegistrationForm token={token}/>}

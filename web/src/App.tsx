import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import { Element } from "./screens/Element/Element";
import { EmailLogin } from "./screens/EmailLogin/EmailLogin";
import { Register } from "./screens/Register/Register";
import { UserPreference } from "./screens/UserPreference/UserPreference";
import AddProperty from "./screens/AddProperty/AddProperty";
import { Properties } from "./screens/Properties/Properties";
import PropertyDetails from "./screens/Properties/PropertyDetails";
import Profile from "./screens/Profile/Profile";
import RequestContract from "./screens/Properties/RequestContract";
import Contracts from "./screens/Contracts/Contracts";
import AttachContract from "./screens/Contracts/AttachContract";
import PayFirstRent from "./screens/Contracts/PayFirstRent";

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Element />} />
        <Route path="/email-login" element={<EmailLogin />} />
        <Route path="/register" element={<Register />} />
        <Route path="/user-preference" element={<UserPreference />} />
        <Route path="/add-property" element={<AddProperty />} />
        <Route path="/properties" element={<Properties />} />
        <Route path="/properties/:id" element={<PropertyDetails />} />
        <Route path="/profile" element={<Profile />} />
  <Route path="/contratos" element={<Contracts />} />
  <Route path="/contratos/:id/anexar" element={<AttachContract />} />
  <Route path="/contratos/:id/pagar" element={<PayFirstRent />} />
        <Route path="/properties/:id/request" element={<RequestContract />} />
      </Routes>
    </Router>
  );
}

export default App;
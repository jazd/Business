using System;
namespace Core
{
    public class Version
    {
        public Version() {}

        public string Name { get; set; }
        public string Build { get; set; }
        public string Value { get; set; }

        public override string ToString() {
            if(Value == null)
                return "0.0.0-Nil";
            if( Build == null)
                return Name + Value;
            else
                return Name + Value + "-" + Build;
        }
    }
}

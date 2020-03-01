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
            if(Name == null)
                return "0.0.0-Nil";
            return Name + Value + "-" + Build;
        }
    }
}

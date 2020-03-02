using System;
namespace Core.Fake
{
    public class Reader : IReader {
        bool IReader.HasRows => throw new NotImplementedException();

        public Reader() {
        }

        public bool HasRows { get { return true; } }

        public string GetString(int i) {
            return "";
        }

        public void Read() {}
    }
}

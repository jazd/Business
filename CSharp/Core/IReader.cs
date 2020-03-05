using System;
namespace Business.Core
{
    public interface IReader
    {
        bool HasRows { get; }

        void Read();
        string GetString(int v);
    }
}

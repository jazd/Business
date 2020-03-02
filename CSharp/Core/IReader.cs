using System;
namespace Core
{
    public interface IReader
    {
        bool HasRows { get; }

        void Read();
        string GetString(int v);
    }
}

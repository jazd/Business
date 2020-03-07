using System;
namespace Business.Core
{
    public interface IReader
    {
        bool HasRows { get; }

        bool Read();
        string GetString(int v);
    }
}

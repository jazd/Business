using System;
namespace Core
{
    public interface IConnection : IDisposable
    {
        void Open();
        void Close();
    }
}
